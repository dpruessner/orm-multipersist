# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'orm-multipersist'
  spec.version       = '0.1.0'
  spec.authors       = ['Daniel Pruessner']
  spec.email         = ['daniel@vcx.bz']

  spec.summary       = 'A multi-database persistence layer for ORMs.'
  spec.description   = 'ORM Multipersist is a library for managing persistence across multiple databases with ease.'
  spec.homepage      = 'https://github.com/dpruessner/orm-multipersist'
  spec.license       = 'MIT'

  # Files and directories
  spec.files         = Dir['lib/**/*', 'README.md', 'LICENSE']
  spec.require_paths = ['lib']

  # Metadata
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/dpruessner/orm-multipersist'
  spec.metadata['changelog_uri'] = 'https://github.com/dpruessner/orm-multipersist/CHANGELOG.md'

  # Required Ruby version
  spec.required_ruby_version = '>= 2.6.0'

  # Add dependencies here
  spec.add_dependency 'activemodel', '>= 7.2.0'
  spec.add_dependency 'sequel', '>= 5.8'
  spec.add_dependency 'sqlite3', '>= 2.1'

  # Development dependencies
  spec.add_development_dependency 'rspec', '>= 3.10'
  spec.add_development_dependency 'rubocop', '>= 1.0'

  # Gem executables (if any)
  # spec.executables = ['bin/orm-multipersist']
end
