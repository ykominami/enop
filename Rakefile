require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

#task :default => :spec

#require 'standalone_migrations'
#StandaloneMigrations::Tasks.load_tasks

# Defining a task called default that depends on the tasks setup, makeconfig, migrate, and integrate.
task default: %w[delete setup makeconfig migrate integrate]

task :enop do
  token="S=s18:U=1f38cb:E=15a831f67b3:C=1532b6e3848:P=1cd:A=en-devtoken:V=2:H=6962d1a884e6b254c480326da6c76fcb"
  url="https://www.evernote.com/shard/s18/notestore"
  sh "bundle exec ruby exe/enop #{token} #{url}"
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

