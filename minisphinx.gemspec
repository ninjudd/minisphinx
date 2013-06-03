lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = "minisphinx"
  gem.version       = IO.read('VERSION')
  gem.authors       = ["Justin Balthrop"]
  gem.email         = ["git@justinbalthrop.com"]
  gem.description   = %q{A simple Sphinx indexing library for Ruby}
  gem.summary       = gem.description
  gem.homepage      = "https://github.com/ninjudd/minisphinx"

  gem.add_development_dependency 'shoulda', '3.0.1'
  gem.add_development_dependency 'mocha'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'activerecord-postgresql-adapter'

  gem.add_dependency 'activerecord', '~> 2.3.9'
  gem.add_dependency 'deep_hash', '0.0.2'

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
