require File.join(File.dirname(__FILE__), '../../lib/sequel/sqlite')

SQLITE_DB = Sequel('sqlite:/')
SQLITE_DB.create_table :items do
  integer :id, :primary_key => true, :auto_increment => true
  text :name
  float :value
end

context "An SQLite database" do
  setup do
    @db = Sequel('sqlite:/')
  end
  
  specify "should provide a list of existing tables" do
    @db.tables.should == []
    
    @db.create_table :testing do
      text :name
    end
    @db.tables.should include(:testing)
  end
  
  specify "should support getting pragma values" do
    @db.pragma_get(:auto_vacuum).should == '0'
  end
  
  specify "should support setting pragma values" do
    @db.pragma_set(:auto_vacuum, '1')
    @db.pragma_get(:auto_vacuum).should == '1'
  end
  
  specify "should support getting and setting the auto_vacuum pragma" do
    @db.auto_vacuum = :full
    @db.auto_vacuum.should == :full
    @db.auto_vacuum = :none
    @db.auto_vacuum.should == :none
    
    proc {@db.auto_vacuum = :invalid}.should raise_error(SequelError)
  end

  specify "should support getting and setting the synchronous pragma" do
    @db.synchronous = :off
    @db.synchronous.should == :off
    @db.synchronous = :normal
    @db.synchronous.should == :normal
    @db.synchronous = :full
    @db.synchronous.should == :full
    
    proc {@db.synchronous = :invalid}.should raise_error(SequelError)
  end
  
  specify "should support getting and setting the temp_store pragma" do
    @db.temp_store = :default
    @db.temp_store.should == :default
    @db.temp_store = :file
    @db.temp_store.should == :file
    @db.temp_store = :memory
    @db.temp_store.should == :memory
    
    proc {@db.temp_store = :invalid}.should raise_error(SequelError)
  end
end

context "An SQLite dataset" do
  setup do
    @d = SQLITE_DB[:items]
    @d.delete # remove all records
  end
  
  specify "should return the correct record count" do
    @d.count.should == 0
    @d << {:name => 'abc', :value => 1.23}
    @d << {:name => 'abc', :value => 4.56}
    @d << {:name => 'def', :value => 7.89}
    @d.count.should == 3
  end
  
  specify "should return the last inserted id when inserting records" do
    id = @d << {:name => 'abc', :value => 1.23}
    id.should == @d.first[:id]
  end
  
  specify "should update records correctly" do
    @d << {:name => 'abc', :value => 1.23}
    @d << {:name => 'abc', :value => 4.56}
    @d << {:name => 'def', :value => 7.89}
    @d.filter(:name => 'abc').update(:value => 5.3)
    
    # the third record should stay the same
    @d[:name => 'def'][:value].should == 7.89
    @d.filter(:value => 5.3).count.should == 2
  end
  
  specify "should delete records correctly" do
    @d << {:name => 'abc', :value => 1.23}
    @d << {:name => 'abc', :value => 4.56}
    @d << {:name => 'def', :value => 7.89}
    @d.filter(:name => 'abc').delete
    
    @d.count.should == 1
    @d.first[:name].should == 'def'
  end
end