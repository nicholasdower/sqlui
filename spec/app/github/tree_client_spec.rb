# frozen_string_literal: true

require_relative '../../../app/github/tree_client'
require_relative '../../spec_helper'

describe Github::TreeClient do
  let(:tree_client) { Github::TreeClient.new(access_token: access_token, cache: cache) }
  let(:access_token) { 'some token' }
  let(:cache) { Github::Cache.new({}) }

  describe '#get_tree' do
    subject { tree_client.get_tree(owner: owner, repo: repo, ref: branch, regex: regex) }

    let(:owner) { 'some_owner' }
    let(:repo) { 'some_repo' }
    let(:branch) { 'some_branch' }
    let(:caching_client) { instance_double(Github::CachingClient) }
    let(:tree_url) { 'https://api.github.com/repos/some_owner/some_repo/git/trees/some_branch?recursive=true' }

    before do
      allow(Github::CachingClient).to receive(:new).and_return(caching_client)
      allow(caching_client)
        .to receive(:get_with_caching)
        .with(tree_url, cache_for: Github::TreeClient::DEFAULT_MAX_TREE_CACHE_AGE_SECONDS)
        .and_return(tree_response)
    end

    context 'when the response has matching paths' do
      let(:tree_response) do
        {
          'sha' => 'some_sha',
          'truncated' => false,
          'tree' => [
            {
              'path' => 'some_path',
              'url' => 'https://api.github.com/repos/some_owner/some_repo/git/blobs/sha_one'
            },
            {
              'path' => 'some_other_path',
              'url' => 'https://api.github.com/repos/some_owner/some_repo/git/blobs/sha_two'
            },
            {
              'path' => 'not_a_match',
              'url' => 'https://api.github.com/repos/some_owner/some_repo/git/blobs/sha_three'
            }
          ]
        }
      end
      let(:regex) { /some.*/ }
      let(:files) do
        [
          Github::File.new(
            owner: owner,
            repo: repo,
            ref: branch,
            tree_sha: 'some_sha',
            path: 'some_path',
            content: 'some_content'
          ),
          Github::File.new(
            owner: owner,
            repo: repo,
            ref: branch,
            tree_sha: 'some_sha',
            path: 'some_other_path',
            content: 'some_other_content'
          )
        ]
      end

      before do
        allow(caching_client)
          .to receive(:get_with_caching)
          .with(
            'https://api.github.com/repos/some_owner/some_repo/git/blobs/sha_one',
            cache_for: Github::TreeClient::DEFAULT_MAX_FILE_CACHE_AGE_SECONDS
          )
          .and_return({ 'content' => Base64.encode64('some_content') })

        allow(caching_client)
          .to receive(:get_with_caching)
          .with(
            'https://api.github.com/repos/some_owner/some_repo/git/blobs/sha_two',
            cache_for: Github::TreeClient::DEFAULT_MAX_FILE_CACHE_AGE_SECONDS
          )
          .and_return({ 'content' => Base64.encode64('some_other_content') })
      end

      it 'returns a tree with the matching paths' do
        expect(subject).to eq(Github::Tree.new(owner: owner, repo: repo, ref: branch, files: files, truncated: false))
      end
    end
  end
end
