# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in enop.gemspec
gemspec

group :development do
  gem 'yard', '~> 0.9.36'
end

gem 'activerecord', '~> 7.1.3.4'
gem 'arxutils_sqlite3'
gem 'ykxutils'
gem 'ykutils', '~> 0.1.10'

gem 'evernote_oauth', '~> 0.2.3'

group :test, :development, optional: true do
  # gem 'rake', '~> 13.1.0'
  gem 'rake'
  gem 'rspec', '~> 3.13.0'
  gem 'rubocop'
  gem 'rubocop-performance'
  gem 'rubocop-rake', require: false
  gem 'rubocop-rspec', require: false
end

group :development do
  gem 'debug', platforms: %i[mri mswin mswin64 mingw x64_mingw]
  gem 'rufo'
end

gem 'rexml', '~> 3.2.9'

