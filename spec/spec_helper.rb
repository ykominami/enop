# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "enop"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# テスト用のEnopインスタンス作成
class TestSetup
  def self.setup(token, url, env)
    token_x, url_x, hash = Enop::Cli.setup
    # puts "token_x=", token_x
    unless token
      token = token_x
      url = url_x
    end
    hash["env"] = env if env
    enop = Enop::Enop.new(
      token,
      url,
      hash
    )
    enop.connect
    enop
  end
end
