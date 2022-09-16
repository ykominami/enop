require 'arxutils_sqlite3'
require 'arxutils_sqlite3/rake_task'

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

#task :default => :spec

#require 'standalone_migrations'
#StandaloneMigrations::Tasks.load_tasks

# Defining a task called default that depends on the tasks setup, makeconfig, migrate, and integrate.
# task default: %w[integrate spec]

#require "rake/testtask"

#Rake::TestTask.new do |t|
#  t.libs  << "test"
#end

#desc "Run test"
#task default: :test

desc "Evernote related operaion"
task default: %i[spec rubocop]

desc "Evernote related operaion"
task :enop do
  sh "bundle exec ruby exe/enop"
end

# Defining a task called default that depends on the tasks setup, makeconfig, migrate, and acr.

