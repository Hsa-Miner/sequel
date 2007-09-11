require File.join(File.dirname(__FILE__), 'spec_helper')

Sequel::Model.db = MODEL_DB = MockDatabase.new

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
  
  it "allows table name change" do
    @model.set_table_name :foo
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
    o.save
    MODEL_DB.sqls.should == ['INSERT INTO items (x) VALUES (2);']
  end
end
