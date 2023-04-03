# frozen_string_literal: true

require_relative '../checks'

module Github
  # A GitHub file.
  class File
    include Checks

    attr_reader :display_path, :content, :github_url

    def initialize(owner:, repo:, branch:, path:, content:)
      check_non_empty_string(owner: owner, repo: repo, branch: branch, path: path)
      @content = check_is_a(content: [String, content])
      @display_path = "#{owner}/#{repo}/#{branch}/#{path}"
      @github_url = "https://github.com/#{owner}/#{repo}/blob/#{branch}/#{path}"
    end
  end
end
