Gem::Specification.new do |s|
  s.name          = 'sqlui'
  s.version       = File.read('.version')
  s.authors       = ['Nick Dower']
  s.email         = 'nicholasdower@gmail.com'
  s.summary       = 'A SQL UI.'
  s.description   = 'A SQL UI.'
  s.homepage      = 'https://github.com/nicholasdower/sqlui'
  s.files         = ['lib/sqlui.rb', 'resources/sqlui.css', 'resources/sqlui.js', 'resources/sqlui.html']
  s.require_paths = [ 'lib' ]

  s.add_development_dependency 'rspec-core', '~> 3.0'
  s.add_development_dependency 'rspec-expectations', '~> 3.0'
  s.add_development_dependency 'rspec-mocks', '~> 3.0'
  s.add_development_dependency 'puma', '~> 6.0'
  s.add_development_dependency 'sinatra', '~> 3.0'
end
