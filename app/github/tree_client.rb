# frozen_string_literal: true

require 'base64'
require 'concurrent/executor/fixed_thread_pool'
require 'json'
require 'logger'
require 'rest-client'

require_relative 'caching_client'
require_relative 'client'
require_relative 'paths'
require_relative 'tree'
require_relative '../checks'
require_relative '../count_down_latch'

module Github
  # Wraps a Github::Client to provide tree-specific features.
  class TreeClient
    include Checks

    @thread_pool = Concurrent::FixedThreadPool.new(5)

    class << self
      attr_reader :thread_pool
    end

    DEFAULT_MAX_TREE_CACHE_AGE_SECONDS = 60 * 5 # 5 minutes
    DEFAULT_MAX_FILE_CACHE_AGE_SECONDS = 60 * 60 * 24 * 7 # 1 week

    MAX_TREE_SIZE = 50
    private_constant :MAX_TREE_SIZE

    def initialize(access_token:, cache:, logger: Logger.new($stdout))
      check_non_empty_string(access_token: access_token)
      check_is_a(cache: [Cache, cache])

      @client = Github::CachingClient.new(Github::Client.new(access_token: access_token, logger: logger), cache)
      @logger = check_non_nil(logger: logger)
    end

    def get_tree(owner:, repo:, ref:, regex:, cache: true)
      check_non_empty_string(owner: owner, repo: repo, ref: ref)
      check_is_a(regex: [Regexp, regex])

      response = if cache
                   @client.get_with_caching(
                     "https://api.github.com/repos/#{owner}/#{repo}/git/trees/#{ref}?recursive=true",
                     cache_for: DEFAULT_MAX_TREE_CACHE_AGE_SECONDS
                   )
                 else
                   @client.get_without_caching("https://api.github.com/repos/#{owner}/#{repo}/git/trees/#{ref}?recursive=true")
                 end

      response['tree'] = response['tree'].select { |blob| regex.match?(blob['path']) }
      raise "trees with more than #{MAX_TREE_SIZE} blobs not supported" if response['tree'].size > MAX_TREE_SIZE

      latch = CountDownLatch.new(response['tree'].size)
      response['tree'].each do |blob|
        TreeClient.thread_pool.post do
          blob['content'] =
            get_file_content_with_caching(owner: owner, repo: repo, path: blob['path'], ref: response['sha'])
        ensure
          latch.count_down
        end
      end

      latch.await(timeout: 10)
      raise 'failed to load saved files' unless response['tree'].all? { |blob| blob['content'] }

      Tree.for(owner: owner, repo: repo, ref: ref, tree_response: response)
    end

    def create_commit_with_file(owner:, repo:, base_sha:, branch:, path:, content:, author_name:, author_email:)
      check_non_empty_string(
        owner: owner,
        repo: repo,
        base_sha: base_sha,
        branch: branch,
        path: path,
        content: content,
        author_name: author_name,
        author_email: author_email
      )

      begin
        @client.get_without_caching("https://api.github.com/repos/#{owner}/#{repo}/git/ref/#{branch}")
        raise "branch already exists: #{owner}/#{repo}/#{branch}"
      rescue RestClient::NotFound
        # ignored
      end

      blob_response = @client.post(
        "https://api.github.com/repos/#{owner}/#{repo}/git/blobs",
        {
          content: Base64.encode64(content),
          encoding: 'base64'
        }
      )
      tree_response = @client.post(
        "https://api.github.com/repos/#{owner}/#{repo}/git/trees",
        {
          base_tree: base_sha,
          tree: [
            {
              path: path,
              mode: '100644',
              type: 'blob',
              sha: check_non_empty_string(sha: blob_response['sha'])
            }
          ]
        }
      )
      basename = File.basename(path)
      message = basename.size > 45 ? "Edit […]#{basename[-42..]}" : "Edit #{basename}"
      commit_response = @client.post(
        "https://api.github.com/repos/#{owner}/#{repo}/git/commits",
        {
          message: message,
          author: {
            name: author_name,
            email: author_email,
            date: Time.now.iso8601
          },
          parents: [
            base_sha
          ],
          tree: check_non_empty_string(sha: tree_response['sha'])
        }
      )
      @client.post(
        "https://api.github.com/repos/#{owner}/#{repo}/git/refs",
        {
          ref: "refs/heads/#{branch}",
          sha: check_non_empty_string(sha: commit_response['sha'])
        }
      )
    end

    private

    # Returns the contents of the file at the specified path. Uses the cache.
    def get_file_content_with_caching(owner:, repo:, path:, ref:)
      check_non_empty_string(owner: owner, repo: repo, sha: ref, path: path)

      response = @client.get_with_caching(
        "https://api.github.com/repos/#{owner}/#{repo}/contents/#{path}?ref=#{ref}",
        cache_for: DEFAULT_MAX_FILE_CACHE_AGE_SECONDS
      )
      Base64.decode64(response['content'])
    end
  end
end
