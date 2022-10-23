# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'sqlui'
  spec.description   = 'A SQL UI.'
  spec.summary       = 'A SQL UI.'
  spec.homepage      = 'https://github.com/nicholasdower/sqlui'
  spec.version       = File.read('.version')
  spec.license       = 'MIT'
  spec.authors       = ['Nick Dower']
  spec.email         = 'nicholasdower@gmail.com'

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.required_ruby_version = '>= 3.0.0'
  spec.bindir = 'bin'
  spec.executables << 'sqlui'

  spec.files =
    Dir['lib/**/*'] +
    Dir['app/**/*'] +
    Dir['client/resources/**/*'] +
    ['.version']

  spec.add_dependency 'mysql2',  '~> 0.0'
  spec.add_dependency 'puma',    '~> 6.0'
  spec.add_dependency 'sinatra', '~> 3.0'

  spec.add_development_dependency 'puma',               '~> 6.0'
  spec.add_development_dependency 'rspec-core',         '~> 3.0'
  spec.add_development_dependency 'rspec-expectations', '~> 3.0'
  spec.add_development_dependency 'rspec-mocks',        '~> 3.0'
  spec.add_development_dependency 'rubocop',            '~> 1.0'
  spec.add_development_dependency 'selenium-webdriver', '~> 4.0'
  spec.add_development_dependency 'watir',              '~> 7.0'
end
