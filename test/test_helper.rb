require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'mocha/setup'
require 'pp'

require 'active_record'
require 'minisphinx'
require 'minisphinx/charset'

class Test::Unit::TestCase
end

RAILS_ENV = 'test'
RAILS_ROOT = '/tmp/minisphinx-test'

ActiveRecord::Base.establish_connection(
  :adapter  => "postgresql",
  :host     => "localhost",
  :database => "minisphinx_test"
)
ActiveRecord::Migration.verbose = false
ActiveRecord::Base.connection.client_min_messages = 'panic'
