lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |s|
  s.name        = 'polkastarter-lottery'
  s.version     = '1.3.2'
  s.summary     = "Polkastarter Lottery"
  s.description = "The Polkastarter Lottery calculation system"
  s.authors     = ["Polkastarter", "Miguel"]
  s.email       = 'miguelcma@polkastarter.com'

  s.files       = Dir['{lib}/**/*', 'LICENSE.md', 'README.md']
  s.test_files  = Dir['spec/**/*']

  s.homepage    = 'https://www.polkastarter.com/'
  s.license     = 'MIT'

  s.add_development_dependency 'rspec', '~> 3.10'
  s.add_development_dependency 'pry', '~> 0.14'
end
