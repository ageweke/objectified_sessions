require 'objectified_sessions'

describe ObjectifiedSessions::FieldDefinition do
  def klass
    ObjectifiedSessions::FieldDefinition
  end

  def new_session_class
    out = double("session_class")
    allow(out).to receive(:kind_of?).with(Class).and_return(true)

    dmm = Module.new do
      class << self
        public :define_method, :private
      end
    end
    allow(out).to receive(:_dynamic_methods_module).with().and_return(dmm)
    out
  end

  before :each do
    @session_class = new_session_class
    @dmm = @session_class._dynamic_methods_module
  end

  it "should normalize field names properly" do
    lambda { klass.normalize_name(nil) }.should raise_error(ArgumentError)
    lambda { klass.normalize_name(12345) }.should raise_error(ArgumentError)

    klass.normalize_name(" fOo  ").should == :fOo
    klass.normalize_name(:' fOo ').should == :fOo
    klass.normalize_name(:foo).should == :foo
    klass.normalize_name("foo").should == :foo
  end

  it "should validate its constructor arguments appropriately" do
    lambda { klass.new(double("not_a_class"), :foo, { :type => :normal, :visibility => :private }) }.should raise_error(ArgumentError, /not_a_class/i)
    lambda { klass.new(@session_class, 12345, { :type => :normal, :visibility => :private }) }.should raise_error(ArgumentError, /12345/i)
    lambda { klass.new(@session_class, :foo, { :type => :whatever, :visibility => :private }) }.should raise_error(ArgumentError, /whatever/i)
    lambda { klass.new(@session_class, :foo, { :visibility => :private }) }.should raise_error(ArgumentError, /:type/i)
    lambda { klass.new(@session_class, :foo, { :type => :normal, :visibility => :whatever }) }.should raise_error(ArgumentError, /whatever/i)
    lambda { klass.new(@session_class, :foo, { :type => :normal }) }.should raise_error(ArgumentError, /:visibility/i)
    lambda { klass.new(@session_class, :foo, { :type => :normal, :visibility => :public, :foo => :bar }) }.should raise_error(ArgumentError, /foo/i)
    lambda { klass.new(@session_class, :foo, { :type => :normal, :visibility => :public, :storage => 12345 }) }.should raise_error(ArgumentError, /12345/i)
  end

  it "should return the right storage name" do
    klass.new(@session_class, :foo, { :type => :normal, :visibility => :public }).storage_name.should == 'foo'
  end

  it "should return the right storage name if aliased" do
    klass.new(@session_class, :foo, { :type => :normal, :visibility => :public, :storage => :bar }).storage_name.should == 'bar'
  end

  it "should return the right value for #delete_data_with_storage_name?" do
    klass.new(@session_class, :foo, { :type => :normal, :visibility => :public }).delete_data_with_storage_name?.should_not be
    klass.new(@session_class, :foo, { :type => :inactive, :visibility => :public }).delete_data_with_storage_name?.should_not be
    klass.new(@session_class, :foo, { :type => :retired, :visibility => :public }).delete_data_with_storage_name?.should be
  end

  it "should return the right value for #allow_access_to_data?" do
    klass.new(@session_class, :foo, { :type => :normal, :visibility => :public }).allow_access_to_data?.should be
    klass.new(@session_class, :foo, { :type => :inactive, :visibility => :public }).allow_access_to_data?.should_not be
    klass.new(@session_class, :foo, { :type => :retired, :visibility => :public }).allow_access_to_data?.should_not be
  end

  [ "==", "eql?" ].each do |method_name|
    describe method_name do
      before :each do
        @mn = method_name
        @basis = klass.new(@session_class, :foo, { :type => :normal, :visibility => :public })
      end

      it "should match for fields that are identical" do
        expect(@basis.send(@mn, klass.new(@session_class, :foo, { :type => :normal, :visibility => :public }))).to be_true
        expect(@basis.send(@mn, klass.new(@session_class, :foo, { :type => :normal, :visibility => :public, :storage => :foo }))).to be_true
      end

      it "should not match if the session class is different" do
        session_class_2 = new_session_class
        expect(@basis.send(@mn, klass.new(session_class_2, :foo, { :type => :normal, :visibility => :public, :storage => :foo }))).not_to be_true
      end

      it "should not match if the name is different" do
        expect(@basis.send(@mn, klass.new(@session_class, :bar, { :type => :normal, :visibility => :public }))).not_to be_true
      end

      it "should not match if the type is different" do
        expect(@basis.send(@mn, klass.new(@session_class, :foo, { :type => :inactive, :visibility => :public }))).not_to be_true
        expect(@basis.send(@mn, klass.new(@session_class, :foo, { :type => :retired, :visibility => :public }))).not_to be_true
      end

      it "should not match if the visibility is different" do
        expect(@basis.send(@mn, klass.new(@session_class, :bar, { :type => :normal, :visibility => :private }))).not_to be_true
      end

      it "should not match if the storage is different" do
        expect(@basis.send(@mn, klass.new(@session_class, :bar, { :type => :normal, :visibility => :public, :storage => :baz }))).not_to be_true
      end
    end
  end

  context "with dynamic-methods module testing" do
    before :each do
      dmm = @dmm
      @underlying_session = double("underlying_session")

      @dmm_class = Class.new do
        include dmm

        def initialize(h)
          @h = h
        end

        def [](x)
          @h[x]
        end

        def []=(x, y)
          @h[x] = y
        end
      end

      @instance = @dmm_class.new(@underlying_session)
    end

    it "should create methods on the dynamic-methods module for a normal field" do
      field = klass.new(@session_class, :foo, { :type => :normal, :visibility => :public })

      expect(@underlying_session).to receive(:[]).once.with(:foo).and_return(:xxx)
      @instance.foo.should == :xxx

      expect(@underlying_session).to receive(:[]=).once.with(:foo, :zzz).and_return(:yyy)
      (@instance.foo = :zzz).should == :zzz
    end

    it "should downcase the field name on the dynamic-methods module for a normal field" do
      field = klass.new(@session_class, :FoO, { :type => :normal, :visibility => :public })

      expect(@underlying_session).to receive(:[]).once.with(:FoO).and_return(:xxx)
      @instance.foo.should == :xxx

      expect(@underlying_session).to receive(:[]=).once.with(:FoO, :zzz).and_return(:yyy)
      (@instance.foo = :zzz).should == :zzz
    end

    it "should create private methods on the dynamic-methods module for a normal field if marked as private" do
      field = klass.new(@session_class, :foo, { :type => :normal, :visibility => :private })

      @instance.respond_to?(:foo).should_not be
      lambda { @instance.foo }.should raise_error(NoMethodError)
      @instance.respond_to?(:foo=).should_not be
      lambda { @instance.foo = 123 }.should raise_error(NoMethodError)

      expect(@underlying_session).to receive(:[]).once.with(:foo).and_return(:xxx)
      @instance.send(:foo).should == :xxx

      expect(@underlying_session).to receive(:[]=).once.with(:foo, :zzz).and_return(:yyy)
      (@instance.send(:foo=, :zzz)).should == :zzz
    end

    it "should not create methods on the dynamic-methods module for an inactive field" do
      field = klass.new(@session_class, :foo, { :type => :inactive, :visibility => :public })

      @instance.respond_to?(:foo).should_not be
      lambda { @instance.send(:foo) }.should raise_error(NoMethodError)
      @instance.respond_to?(:foo=).should_not be
      lambda { @instance.send(:foo=, 123) }.should raise_error(NoMethodError)
    end

    it "should not create methods on the dynamic-methods module for a retired field" do
      field = klass.new(@session_class, :foo, { :type => :retired, :visibility => :public })

      @instance.respond_to?(:foo).should_not be
      lambda { @instance.send(:foo) }.should raise_error(NoMethodError)
      @instance.respond_to?(:foo=).should_not be
      lambda { @instance.send(:foo=, 123) }.should raise_error(NoMethodError)
    end
  end
end
