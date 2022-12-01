# frozen_string_literal: true

class Version
  SQLUI = File.read(File.expand_path(File.join(__dir__, '..', '.release-version'))).strip
end
