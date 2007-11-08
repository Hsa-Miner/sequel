# Array extensions
class Array
  # Concatenates an array of strings into an SQL string. ANSI SQL and C-style
  # comments are removed, as well as excessive white-space.
  def to_sql
    map {|l| (l =~ /^(.*)--/ ? $1 : l).chomp}.join(' '). \
      gsub(/\/\*.*\*\//, '').gsub(/\s+/, ' ').strip
  end
end

module Sequel
  # LiteralString is used to represent literal SQL expressions. An 
  # LiteralString is copied verbatim into an SQL statement. Instances of
  # LiteralString can be created by calling String#expr.
  class LiteralString < ::String
  end
end

# String extensions
class String
  # Converts a string into an SQL string by removing comments.
  # See also Array#to_sql.
  def to_sql
    split($/).to_sql
  end
  
  # Splits a string into separate SQL statements, removing comments
  # and excessive white-space.
  def split_sql
    to_sql.split(';').map {|s| s.strip}
  end

  # Converts a string into an LiteralString, in order to override string
  # literalization, e.g.:
  #
  #   DB[:items].filter(:abc => 'def').sql #=>
  #     "SELECT * FROM items WHERE (abc = 'def')"
  #
  #   DB[:items].filter(:abc => 'def'.lit).sql #=>
  #     "SELECT * FROM items WHERE (abc = def)"
  #
  def lit
    Sequel::LiteralString.new(self)
  end
  
  alias_method :expr, :lit
  
  # Converts a string into a Time object.
  def to_time
    Time.parse(self)
  end
end


module Sequel
  module SQL
    class Expression
      def lit; self; end
    end
    
    class ColumnExpr < Expression
      def initialize(l, op, r = nil); @l, @op, @r = l, op, r; end
      
      def to_s(ds)
        @r ? \
          "#{ds.literal(@l)} #{@op} #{ds.literal(@r)}" : \
          "#{ds.literal(@l)} #{@op}"
      end
    end
    
    class Function < Expression
      def initialize(f, *args); @f, @args = f, args; end

      def to_s(ds)
        args = @args.empty? ? '' : ds.literal(@args)
        "#{@f}(#{args})"
      end
    end
    
    class ColumnAll < Expression
      def initialize(t); @t = t; end
      def to_s(ds); "#{@t}.*"; end
    end
    
    module ColumnMethods
      AS = 'AS'.freeze
      DESC = 'DESC'.freeze
      ASC = 'ASC'.freeze
      
      def as(a); ColumnExpr.new(self, AS, a); end
      alias_method :AS, :as
      
      def desc; ColumnExpr.new(self, DESC); end
      alias_method :DESC, :desc
      
      def asc; ColumnExpr.new(self, ASC); end
      alias_method :ASC, :asc
    end
  end
end

class Object
  include Sequel::SQL::ColumnMethods
end

class Symbol
  def [](*args); Sequel::SQL::Function.new(self, *args); end
  
  COLUMN_REF_RE1 = /^(\w+)__(\w+)___(\w+)/.freeze
  COLUMN_REF_RE2 = /^(\w+)___(\w+)$/.freeze
  COLUMN_REF_RE3 = /^(\w+)__(\w+)$/.freeze

  # Converts a symbol into a column name. This method supports underscore
  # notation in order to express qualified (two underscores) and aliased 
  # (three underscores) columns:
  #
  #   ds = DB[:items]
  #   :abc.to_column_ref(ds) #=> "abc"
  #   :abc___a.to_column_ref(ds) #=> "abc AS a"
  #   :items__abc.to_column_ref(ds) #=> "items.abc"
  #   :items__abc___a.to_column_ref(ds) #=> "items.abc AS a"
  #
  def to_column_ref(ds)
    case s = to_s
    when COLUMN_REF_RE1: "#{$1}.#{ds.quote_column_ref($2)} AS #{ds.quote_column_ref($3)}"
    when COLUMN_REF_RE2: "#{ds.quote_column_ref($1)} AS #{ds.quote_column_ref($2)}"
    when COLUMN_REF_RE3: "#{$1}.#{ds.quote_column_ref($2)}"
    else                 ds.quote_column_ref(s)
    end
  end
  
  def all; Sequel::SQL::ColumnAll.new(self); end
  alias_method :ALL, :all

  # Converts missing method calls into functions on columns, if the
  # method name is made of all upper case letters.
  def method_missing(sym)
    if ((s = sym.to_s) =~ /^([A-Z]+)$/)
      Sequel::SQL::Function.new(s.downcase, self)
    else
      super
    end
  end
  
  def cast_as(t)
    if t.is_a?(Symbol)
      t = t.to_s.lit
    end
    Sequel::SQL::Function.new(:cast, self.as(t))
  end
end
