require File.join(File.dirname(__FILE__), 'spec_helper')

Sequel::Model.db = MODEL_DB = MockDatabase.new

context "A model class" do
  specify "should be associated with a dataset" do
    @m = Class.new(Sequel::Model) do
      set_dataset MODEL_DB[:items]
    end
    
    @m.dataset.should be_a_kind_of(MockDataset)
    @m.dataset.opts[:from].should == [:items]

    @m2 = Class.new(Sequel::Model) do
      set_dataset MODEL_DB[:zzz]
    end
    
    @m2.dataset.should be_a_kind_of(MockDataset)
    @m2.dataset.opts[:from].should == [:zzz]
    @m.dataset.opts[:from].should == [:items]
  end
end

context "A model's primary key" do
  specify "should default to id" do
    @m = Class.new(Sequel::Model) do
    end
    
    @m.primary_key.should == :id
  end
  
  specify "should be changeable through Model.set_primary_key" do
    @m = Class.new(Sequel::Model) do
      set_primary_key :xxx
    end
    
    @m.primary_key.should == :xxx
  end
  
  specify "should support composite primary keys" do
    @m = Class.new(Sequel::Model) do
      set_primary_key [:node_id, :session_id]
    end
    @m.primary_key.should == [:node_id, :session_id]
  end
end

context "A model without a primary key" do
  setup do
    @m = Class.new(Sequel::Model) do
      no_primary_key
    end
  end
  
  specify "should return nil for primary_key" do
    @m.primary_key.should be_nil
  end
  
  specify "should raise on #this" do
    o = @m.new
    proc {o.this}.should raise_error(SequelError)
  end
end

context "Model#this" do
  setup do
    @m = Class.new(Sequel::Model(:items)) do
    end
  end
  
  specify "should return a dataset identifying the record" do
    o = @m.new(:id => 3)
    o.this.sql.should == "SELECT * FROM items WHERE (id = 3)"
  end
  
  specify "should support arbitrary primary keys" do
    @m.set_primary_key(:xxx)
    
    o = @m.new(:xxx => 3)
    o.this.sql.should == "SELECT * FROM items WHERE (xxx = 3)"
  end
  
  specify "should support composite primary keys" do
    @m.set_primary_key [:x, :y]
    o = @m.new(:x => 4, :y => 5)

    o.this.sql.should =~ /^SELECT \* FROM items WHERE (\(x = 4\) AND \(y = 5\))|(\(y = 5\) AND \(x = 4\))$/
  end
end

context "A new model instance" do
  setup do
    @m = Class.new(Sequel::Model) do
      set_dataset MODEL_DB[:items]
    end
  end
  
  specify "should be marked as new?" do
    o = @m.new
    o.should be_new
  end
  
  specify "should not be marked as new? once it is saved" do
    o = @m.new(:x => 1)
    o.should be_new
    o.save
    o.should_not be_new
  end
  
  specify "should use the last inserted id as primary key if not in values" do
    d = @m.dataset
    def d.insert(*args)
      super
      1234
    end
    
    o = @m.new(:x => 1)
    o.save
    o.id.should == 1234
    
    o = @m.new(:x => 1, :id => 333)
    o.save
    o.id.should == 333
  end
end

describe Sequel::Model do
  before do
    @model = Class.new(Sequel::Model(:items))
  end
  
  it "creates dynamic model subclass with set table name" do
    @model.table_name.should == :items
  end
  
  it "defaults to primary key of id" do
    @model.primary_key.should == :id
  end
  
  it "allow primary key change" do
    @model.set_primary_key :ssn
    @model.primary_key.should == :ssn
  end
  
  it "allows dataset change" do
    @model.set_dataset(MODEL_DB[:foo])
    @model.table_name.should == :foo
  end
  
  it "sets schema with implicit table name" do
    @model.set_schema do
      primary_key :ssn, :string
    end
    @model.primary_key.should == :ssn
    @model.table_name.should == :items
  end
  
  it "sets schema with explicit table name" do
    @model.set_schema :foo do
      primary_key :id
    end
    @model.primary_key.should == :id
    @model.table_name.should == :foo
  end

  it "puts the lotion in the basket or it gets the hose again" do
    # just kidding!
  end
end

class DummyModelBased < Sequel::Model(:blog)
end

context "Sequel::Model()" do
  specify "should allow reopening of descendant classes" do
    proc do
      eval "class DummyModelBased < Sequel::Model(:blog); end"
    end.should_not raise_error
  end
end

context "A model class" do
  setup do
    MODEL_DB.reset
    @c = Class.new(Sequel::Model(:items))
  end
  
  specify "should be able to create rows in the associated table" do
    o = @c.create(:x => 1)
    o.class.should == @c
    MODEL_DB.sqls.should == ['INSERT INTO items (x) VALUES (1);']
  end
  
  specify "should be able to create rows without any values specified" do
    o = @c.create
    o.class.should == @c
    MODEL_DB.sqls.should == ['INSERT INTO items DEFAULT VALUES;']
  end
end

context "A model class without a primary key" do
  setup do
    MODEL_DB.reset
    @c = Class.new(Sequel::Model(:items)) do
      no_primary_key
    end
  end
  
  specify "should be able to insert records without selecting them back" do
    i = nil
    proc {i = @c.create(:x => 1)}.should_not raise_error
    i.class.should be(@c)
    i.values.should == {:x => 1}
    
    MODEL_DB.sqls.should == ['INSERT INTO items (x) VALUES (1);']
  end
  
  specify "should raise when deleting" do
    o = @c.new
    proc {o.delete}.should raise_error
  end

  specify "should insert a record when saving" do
    o = @c.new(:x => 2)
    o.should be_new
    o.save
    MODEL_DB.sqls.should == ['INSERT INTO items (x) VALUES (2);']
  end
end

context "Model#serialize" do
  setup do
    MODEL_DB.reset
  end
  
  specify "should translate values to YAML when creating records" do
    @c = Class.new(Sequel::Model(:items)) do
      no_primary_key
      serialize :abc
    end

    o = @c.create(:abc => 1)
    o.values[:abc].should == "--- 1\n"
    o = @c.create(:abc => "hello")
    o.values[:abc].should == "--- hello\n"
    
    MODEL_DB.sqls.should == [ \
      "INSERT INTO items (abc) VALUES ('--- 1\n');", \
      "INSERT INTO items (abc) VALUES ('--- hello\n');", \
    ]
  end
  
  specify "should translate values to and from YAML using accessor methods" do
    @c = Class.new(Sequel::Model(:items)) do
      serialize :abc, :def
    end
    
    o = @c.new(:id => 1, :abc => "--- 1\n", :def => "--- hello\n")
    o.values.should == {:id => 1, :abc => "--- 1\n", :def => "--- hello\n"}
    o.abc.should == 1
    o.def.should == 'hello'
    
    o.abc = 23
    o.values[:abc].should == "--- 23\n"
    o.save
    
    MODEL_DB.sqls.first.should =~ /abc = '--- 23\n'/
  end
end
