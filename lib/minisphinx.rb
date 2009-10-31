module Minisphinx
  def sphinx_source(name, opts)
    opts[:model_class] ||= self
    Minisphinx.sources << Source.new(name, opts)
  end

  def sphinx_index(name, opts = {})
    Minisphinx.indexes << Index.new(name, opts)
  end

  def self.indexes; @indexes ||= []; end
  def self.sources; @sources ||= []; end

  def self.configure(opts)
    template = ['default', RAILS_ENV].collect {|base| RAILS_ROOT + "/config/sphinx/#{base}.conf"}.detect {|file| File.exists?(file)}
    
    File.open(opts[:path] + '/sphinx.conf', 'w') do |file|
      file << "# Autogenerated by minisphinx at #{Time.now}\n"
      file << ERB.new(IO.read(template)).result(binding)
      file << "\n# Sources\n"
      sources.each do |source|
        file << source.to_s + "\n\n"
      end
      file << "\n# Indexes\n"
      indexes.each do |index|
        index.path = opts[:path]
        file << index.to_s + "\n\n"
      end
    end
  end

  def self.config_block(head, lines)
    "#{head}\n{\n  #{lines.flatten.compact.join("\n  ")}\n}"
  end

  class Source
    attr_reader :name, :model_class, :fetch_key, :db, :fields, :joins, :config
    
    def initialize(name, opts)
      @name      = name
      @fetch_key = opts.delete(:fetch_key) || 'id'

      @fields = initialize_fields(opts)
      @joins  = Array(opts.delete(:joins)) + Array(opts.delete(:join))
      (opts.delete(:include) || []).each do |include_opts|
        @fields.concat initialize_fields(include_opts)
        @joins.concat  Array(include_opts.delete(:joins)) + Array(include_opts.delete(:join))
      end
      raise 'at least one field required' if @fields.empty?
      @fields.sort!

      @model_class = opts.delete(:model_class)
      @table_name  = opts.delete(:table_name)
      @db = opts.delete(:db) || model_class.connection.config
      @db = ActiveRecord::Base.configurations["#{db}_#{RAILS_ENV}"] unless db.kind_of?(Hash)

      @config = self.class.config.merge(opts)
    end

    def table_name
      @table_name ||= model_class.table_name
    end

    def type
      db[:adapter] == 'postgresql' ? 'pgsql' : db[:adapter]
    end

    def to_s
      Minisphinx.config_block("source #{name}", [ 
        "type = #{type}",
        config.collect do |key, value|
          "sql_#{key} = #{value}"
        end,
        "sql_db   = #{db[:database]}",
        "sql_host = #{db[:host]}",
        "sql_pass = #{db[:password]}",
        "sql_user = #{db[:username]}",
        "sql_query_range = #{sql_query_range}",
        "sql_query = #{sql_query}",
        "sql_query_info = #{sql_query_info}",
        fields.collect do |field|
          "sql_attr_#{field.type} = #{field.name}" if field.type != :string
        end,
      ])
    end

    def sql_query_range
      "SELECT coalesce(MIN(#{fetch_key}),1)::bigint, coalesce(MAX(#{fetch_key}),1)::bigint FROM #{table_name}"
    end

    def sql_query
      "SELECT #{table_name}.id AS doc_id, #{fields.join(', ')} " <<
        "FROM #{table_name} #{joins.join(' ')} WHERE #{fetch_key} >= $start AND #{fetch_key} <= $end"
    end

    def sql_query_info
      "SELECT * FROM #{table_name} WHERE id = $id"
    end

    def self.config
      @config ||= {
        :range_step => 5000,
        :ranged_throttle => 0,
      }
    end

  private

    def initialize_fields(opts)
      (opts.delete(:fields) || []).collect do |field_opts|
        field_opts = {:field => field_opts} unless field_opts.kind_of?(Hash)
        field_opts[:table_name]  = opts[:table_name]
        field_opts[:model_class] = opts[:model_class]
        [Field.new(field_opts), field_opts[:sortable] && Field.new(field_opts.merge(:type => :sortable, :suffix => 'sortable'))]
      end.flatten.compact
    end
  end

  class Field
    attr_reader :model_class, :field, :name, :type

    TYPE_MAP = {
      :integer   => :uint,
      :decimal   => :float,
      :boolean   => :bool,
      :date      => :timestamp,
      :datetime  => :timestamp,
      :timestamp => :timestamp,
      :text      => :string,
      :sortable  => :str2ordinal,
    }

    def initialize(opts)
      @model_class  = opts[:model_class] 
      @table_name   = opts[:table_name] 

      @type  = opts[:type]
      @name  = opts[:as] || opts[:field]
      @name  = "#{name}_#{opts[:suffix]}" if opts[:suffix]
      @field = opts[:field]
      @field = "#{table_name}.#{field}"   if not field.index(/[\(.\s]/)
      @field = opts[:transform] % field   if opts[:transform]
      @field = "UNIX_TIMESTAMP(#{field})" if type == :timestamp 
    end

    def table_name
      @table_name ||= model_class ? model_class.table_name : nil
    end

    def <=>(other)
      # Sphinx has a bug that messes up your index unless str2ordinal fields come first.
      if type != other.type
        (type == :str2ordinal && -1) || (other.type == :str2ordinal && 1) || (type.to_s <=> other.type.to_s)
      else
        name <=> other.name
      end
    end
    
    def type
      @type ||= (model_class and column = model_class.columns_hash[name]) && column.type.to_sym || :string
      TYPE_MAP[@type] || @type
    end
        
    def to_s
      "#{field} AS #{name}"
    end
  end

  class Index
    attr_reader :name, :sources, :charset, :config

    def initialize(name, opts)
      @name    = name
      @config  = self.class.config.merge(opts)     
      @sources = Array(config.delete(:source)) + Array(config.delete(:sources))
      @charset = Minisphinx::Charset.new(config.delete(:charset)) if config[:charset]
    end

    def to_s
      Minisphinx.config_block("index #{name}", [ 
        sources.collect do |source|
          "source = #{source}"
        end,
        config.collect do |key, value|
          "#{key} = #{value}"
        end,
        charset && "charset_table = #{charset}",
      ])
    end

    def path=(path)
      config[:path] = "#{path}/#{name}"
    end

    def self.config
      @config ||= {
        :charset_type => 'utf-8',
        :min_word_len => 1,
        :html_strip   => 0,
        :docinfo      => 'extern',
      }
    end
  end
end

class ActiveRecord::ConnectionAdapters::AbstractAdapter
  attr_reader :config
end
