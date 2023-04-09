# frozen_string_literal: true

require_relative 'args'

# Config for saved files.
class SavedConfig
  attr_reader :token, :owner, :repo, :branch, :regex, :author_name, :author_email

  def initialize(hash)
    @token = Args.fetch_non_empty_string(hash, :token).strip
    @owner = Args.fetch_non_empty_string(hash, :owner).strip
    @repo = Args.fetch_non_empty_string(hash, :repo).strip
    @branch = Args.fetch_non_empty_string(hash, :branch).strip
    @regex = Regexp.new(Args.fetch_non_empty_string(hash, :regex))
    author = Args.fetch_non_empty_hash(hash, :author)
    @author_name = Args.fetch_non_empty_string(author, :name).strip
    @author_email = Args.fetch_non_empty_string(author, :email).strip
  end
end
