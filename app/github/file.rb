# frozen_string_literal: true

require_relative '../checks'

module Github
  # A GitHub file.
  class File
    include Checks

    attr_reader :display_path, :tree_sha, :content, :github_url

    def initialize(owner:, repo:, branch:, tree_sha:, path:, content:)
      check_non_empty_string(owner: owner, repo: repo, branch: branch, path: path, tree_sha: tree_sha)
      @display_path = "#{owner}/#{repo}/#{branch}/#{path}"
      @tree_sha = tree_sha
      @content = check_is_a(content: [String, content])
      @github_url = "https://github.com/#{owner}/#{repo}/blob/#{branch}/#{path}"
    end

    def ==(other)
      self.class == other.class &&
        @display_path == other.display_path &&
        @tree_sha == other.tree_sha &&
        @content == other.content &&
        @github_url == other.github_url
    end
  end
end
