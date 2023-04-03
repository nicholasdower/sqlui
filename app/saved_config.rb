# frozen_string_literal: true

require_relative 'args'

# Config for saved files.
class SavedConfig
  attr_reader :token, :owner, :repo, :branch, :regex

  def initialize(hash)
    @token = Args.fetch_non_empty_string(hash, :token).strip
    @owner = Args.fetch_non_empty_string(hash, :owner).strip
    @repo = Args.fetch_non_empty_string(hash, :repo).strip
    @branch = Args.fetch_non_empty_string(hash, :branch).strip
    @regex = Regexp.new(Args.fetch_non_empty_string(hash, :regex))
  end
end
