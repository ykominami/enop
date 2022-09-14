require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

#task :default => :spec

#require 'standalone_migrations'
#StandaloneMigrations::Tasks.load_tasks

# Defining a task called default that depends on the tasks setup, makeconfig, migrate, and integrate.
task default: %w[delete setup makeconfig migrate integrate spec]

task :enop do
  sh "bundle exec ruby exe/enop"
end

task scmi: %w[setup makeconfig migrate integrate]

task dscmi: %w[delete setup makeconfig migrate integrate]

task dsc: %w[delete setup makeconfig]

task ds: %w[delete setup]

task s: %w[setup]

task sc: %w[setup makeconfig]

task dscm: %w[delete setup makeconfig migrate]

task scm: %w[setup makeconfig migrate]

task mi: %w[migrate integrate]

task i: %w[integrate]

# コマンドラインで指定したクラス名を含むオプション指定用ハッシュの定義を含むRubyスクリ
# プトファイルの生成
task :setup do
  sh "bundle exec arxutils_sqlite3 --cmd=s --klass=Enop"
end
# DB構成情報の生成
task :makeconfig do
  sh "bundle exec arxutils_sqlite3 --cmd=c"
end
# マイグレート用スクリプトファイルの生成とマイグレートの実行
task :migrate do
  sh "bundle exec arxutils_sqlite3 --cmd=m --yaml=config/db_scheme.yml"
end
task :integrate do
  sh "bundle exec arxutils_sqlite3 --cmd=i"
end

task :delete do
  sh "bundle exec arxutils_sqlite3 --cmd=d"
end

task :delete_db do
  sh "bundle exec arxutils_sqlite3 --cmd=b"
end

