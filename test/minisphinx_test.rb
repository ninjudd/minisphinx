require File.dirname(__FILE__) + '/test_helper'

class MinisphinxTest < Test::Unit::TestCase
  class CreateTables < ActiveRecord::Migration
    def self.up
      create_table :pets do |t|
        t.column :name, :string
        t.column :species, :string
        t.column :breed, :string
        t.column :color, :string
        t.column :gender, :string
        t.column :adopted, :boolean
      end
    end

    def self.down
      drop_table :pets
    end
  end

  class Pet < ActiveRecord::Base
    extend Minisphinx

    def self.initialize_sphinx
      sphinx_source :pets,
        :fetch_key   => 'public_id',
        :delta_field => 'CASE WHEN master_profile THEN now() ELSE updated_at END',
        :fields => [
          {:field => 'name',    :sortable => true},
          {:field => 'species', :sortable => true},
          {:field => 'breed',   :sortable => true},
          {:field => 'gender',  :sortable => true},
          {:field => 'adopted', :type => :boolean},
        ]

      Minisphinx::Index.config[:source ] = :profiles
      Minisphinx::Index.config[:delta  ] = true

      sphinx_index :full
    end
  end

  context 'with a db connection' do
    setup do
      Dir.mkdir('/tmp/minisphinx-test')
      CreateTables.verbose = false
      CreateTables.up
    end

    teardown do
      CreateTables.down
    end

    should "write config" do
      Pet.initialize_sphinx
      Minisphinx.configure(:path => '/tmp/minisphinx-test')
      assert File.exists('/tmp/minisphinx-test/sphinx.conf')
    end
  end
end
