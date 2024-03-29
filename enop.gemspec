# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'enop/version'

Gem::Specification.new do |spec|
  spec.name = 'enop'
  spec.version       = Enop::VERSION
  spec.authors       = ['yasuo kominami']
  spec.email         = ['ykominami@gmail.com']

  spec.summary       = 'utility functions for Evernote API.'
  spec.description   = 'utility functions for Evernote API.'
  spec.homepage      = ''
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  # if spec.respond_to?(:metadata)
  #    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  # else
  #  raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  # end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # spec.add_runtime_dependency 'arxutils_sqlite3'
  # spec.add_runtime_dependency 'ykutils'
  # spec.add_runtime_dependency 'ykxutils'

  # spec.add_runtime_dependency 'evernote_oauth'

  # spec.add_development_dependency 'bundler'
  # spec.add_development_dependency 'rake'
  # spec.add_development_dependency 'rspec'
  # spec.add_development_dependency 'rubocop'
  #  spec.add_development_dependency "rubocop-rake"
  #  spec.add_development_dependency "rubocop-rspec"
  #  spec.add_development_dependency "yard"
  # spec.add_development_dependency 'yard'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
