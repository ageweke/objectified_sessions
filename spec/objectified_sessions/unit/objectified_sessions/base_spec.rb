require 'objectified_sessions'
require 'objectified_sessions/helpers/exception_helpers'

describe ObjectifiedSessions::Base do
  include ObjectifiedSessions::Helpers::ExceptionHelpers

  before :each do
    @class = Class.new(::ObjectifiedSessions::Base)
    @underlying_session = double("underlying_session")
  end

  def allow_prefix!(prefix)
    @prefixed_underlying_session = double("prefixed_underlying_session")
    allow(@underlying_session).to receive(:[]).with(prefix.to_s).and_return(@prefixed_underlying_session)
  end

  def new_instance!
    @instance = @class.new(@underlying_session)
  end

  def expect_and_create_field!(name, storage_name, allow_access_to_data, delete_data_with_storage_name, options)
    out = double("field_#{name}")

    allow(out).to receive(:name).with().and_return(name.to_sym)
    allow(out).to receive(:storage_name).with().and_return(storage_name.to_s)
    allow(out).to receive(:allow_access_to_data?).with().and_return(allow_access_to_data)
    allow(out).to receive(:delete_data_with_storage_name?).with().and_return(delete_data_with_storage_name)
    expect(ObjectifiedSessions::FieldDefinition).to receive(:new).once.with(@class, name, options).and_return(out)

    out
  end

  describe "deletion of unknown fields" do
    before :each do
      allow(@underlying_session).to receive(:keys).with().and_return([ :foo, :bar, :baz ])
    end

    def expect_deletion(expected_deleted_keys)
      expect(@underlying_session).to receive(:delete).once do |keys|
        unless keys.sort_by(&:to_s) == expected_deleted_keys.sort_by(&:to_s)
          raise "Unexpected keys passed: #{keys.inspect}; expected: #{expected_deleted_keys.inspect}"
        end
      end

      new_instance!
    end

    it "should delete unknown fields on startup if unknown_fields == :delete" do
      @class.unknown_fields :delete

      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      expect_deletion([ :bar, :baz ])
    end

    it "should also delete fields that have delete_data_with_storage_name == true" do
      @class.unknown_fields :delete

      @field_foo = expect_and_create_field!(:foo, 'foo', true, true, { :type => :normal, :visibility => :public })
      @class.field :foo

      expect_deletion([ :foo, :bar, :baz ])
    end

    it "should delete fields based on storage name, not name" do
      @class.unknown_fields :delete

      @field_foo = expect_and_create_field!(:foo, 'bar', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      expect_deletion([ :foo, :baz ])
    end

    it "should not delete fields if unknown_fields is not set" do
      @field_foo = expect_and_create_field!(:foo, 'bar', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      new_instance!
    end

    it "should not delete fields if unknown_fields is set to :preserve" do
      @class.unknown_fields :preserve

      @field_foo = expect_and_create_field!(:foo, 'bar', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      new_instance!
    end

    it "should only delete data within the prefix, if one is set" do
      @class.prefix :prf
      @class.unknown_fields :delete

      allow_prefix!(:prf)

      allow(@underlying_session).to receive(:keys).with().and_return([ :foo, :bar, :baz, :prf ])
      allow(@prefixed_underlying_session).to receive(:keys).with().and_return([ :foo, :quux, :marph ])

      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      expect(@prefixed_underlying_session).to receive(:delete).once do |keys|
        unless keys.sort_by(&:to_s) == [ :quux, :marph ].sort_by(&:to_s)
          raise "Unexpected keys passed: #{keys.inspect}"
        end
      end

      new_instance!
    end
  end

  describe "reading fields" do
    before :each do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      new_instance!
    end

    it "should raise if asked for a field that doesn't exist" do
      e = capture_exception(ObjectifiedSessions::Errors::NoSuchFieldError) { @instance.send(:[], :bar) }
      e.session_class.should be(@class)
      e.field_name.should == :bar
      e.message.should match(/bar/i)
      e.message.should match(/foo/i)
    end

    it "should return data if present" do
      allow(@underlying_session).to receive(:[]).with('foo').and_return(123)
      @instance.send(:[], 'foo').should == 123
    end

    it "should return data via the prefix, if one is set" do
      @class.prefix :prf
      allow_prefix!(:prf)

      allow(@prefixed_underlying_session).to receive(:[]).with('foo').and_return(234)
      allow(@underlying_session).to receive(:[]).with('foo').and_return(345)

      @instance.send(:[], 'foo').should == 234
    end

    it "should not bind a hash to the prefix, if none is there" do
      @class.prefix :prf

      allow(@underlying_session).to receive(:[]).with('prf').and_return(nil)

      @instance.send(:[], 'foo').should == nil
    end
  end

  describe "writing fields" do
    before :each do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      new_instance!
    end

    it "should raise if asked for a field that doesn't exist" do
      e = capture_exception(ObjectifiedSessions::Errors::NoSuchFieldError) { @instance.send(:[]=, :bar, 123) }
      e.session_class.should be(@class)
      e.field_name.should == :bar
      e.message.should match(/bar/i)
      e.message.should match(/foo/i)
    end

    it "should assign data" do
      expect(@underlying_session).to receive(:[]=).once.with('foo', 123)
      @instance.send(:[]=, :foo, 123).should == 123
    end

    it "should assign data via the prefix, if one is set" do
      @class.prefix :prf
      allow_prefix!(:prf)

      expect(@prefixed_underlying_session).to receive(:[]=).once.with('foo', 123)

      @instance.send(:[]=, 'foo', 123).should == 123
    end

    it "should bind a hash to the prefix, if none is there" do
      @class.prefix :prf


      @prefixed_underlying_session = double("prefixed_underlying_session")
      expect(@underlying_session).to receive(:[]).once.ordered.with('prf').and_return(nil)
      expect(@underlying_session).to receive(:[]=).once.ordered.with('prf', { })
      expect(@underlying_session).to receive(:[]).once.ordered.with('prf').and_return(@prefixed_underlying_session)

      expect(@prefixed_underlying_session).to receive(:[]=).once.with('foo', 123)
      @instance.send(:[]=, 'foo', 123).should == 123
    end
  end

  describe "defining fields" do
    it "should define a simple field, and make it retrievable" do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      @class._field_named(:foo).should be(@field_foo)
      @class._field_named('foo').should be(@field_foo)
      @class._field_with_storage_name(:foo).should be(@field_foo)
      @class._field_with_storage_name('foo').should be(@field_foo)
    end

    it "should allow you to change the visibility" do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :private })
      @class.field :foo, :visibility => :private

      @class._field_named(:foo).should be(@field_foo)
      @class._field_named('foo').should be(@field_foo)
      @class._field_with_storage_name(:foo).should be(@field_foo)
      @class._field_with_storage_name('foo').should be(@field_foo)
    end

    it "should respect the default visibility" do
      @class.default_visibility :private

      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :private })
      @class.field :foo

      @class._field_named(:foo).should be(@field_foo)
      @class._field_named('foo').should be(@field_foo)
      @class._field_with_storage_name(:foo).should be(@field_foo)
      @class._field_with_storage_name('foo').should be(@field_foo)
    end

    it "should allow you to change the storage name" do
      @field_foo = expect_and_create_field!(:foo, 'bar', true, false, { :type => :normal, :visibility => :public, :storage => :bar })
      @class.field :foo, :storage => :bar

      @class._field_named(:foo).should be(@field_foo)
      @class._field_named('foo').should be(@field_foo)
      @class._field_with_storage_name('foo').should == nil
      @class._field_with_storage_name(:foo).should == nil
      @class._field_with_storage_name(:bar).should be(@field_foo)
      @class._field_with_storage_name('bar').should be(@field_foo)
    end

    it "should raise if you try to define a field with the same name" do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      @field_foo = expect_and_create_field!('foo', 'bar', true, false, { :type => :normal, :visibility => :public, :storage => :bar })
      e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldNameError) do
        @class.field 'foo', :storage => :bar
      end
      e.session_class.should be(@class)
      e.field_name.should == :foo
      e.message.should match(/foo/i)
    end

    it "should raise if you try to define a field with the same storage name" do
      @field_foo = expect_and_create_field!(:foo, 'foo', true, false, { :type => :normal, :visibility => :public })
      @class.field :foo

      @field_foo = expect_and_create_field!('bar', 'foo', true, false, { :type => :normal, :visibility => :public, :storage => :foo })
      e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldStorageNameError) do
        @class.field 'bar', :storage => :foo
      end
      e.session_class.should be(@class)
      e.original_field_name.should == :foo
      e.new_field_name.should == :bar
      e.storage_name.should == 'foo'
      e.message.should match(/foo/i)
      e.message.should match(/bar/i)
    end

    describe "inactive fields" do
      it "should allow defining an inactive field" do
        @field_foo = expect_and_create_field!(:foo, 'foo', false, false, { :type => :inactive, :visibility => :public })
        @class.inactive :foo

        @class._field_named(:foo).should be(@field_foo)
        @class._field_named('foo').should be(@field_foo)
        @class._field_with_storage_name(:foo).should be(@field_foo)
        @class._field_with_storage_name('foo').should be(@field_foo)
      end

      it "should conflict with a normal field" do
        @field_foo = expect_and_create_field!(:foo, 'foo', false, false, { :type => :inactive, :visibility => :public })
        @class.inactive :foo

        @field_foo = expect_and_create_field!('foo', 'bar', true, false, { :type => :normal, :visibility => :public, :storage => :bar })
        e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldNameError) do
          @class.field 'foo', :storage => :bar
        end
        e.session_class.should be(@class)
        e.field_name.should == :foo
        e.message.should match(/foo/i)
      end

      it "should raise if you try to define a field with the same storage name" do
        @field_foo = expect_and_create_field!(:foo, 'foo', false, false, { :type => :inactive, :visibility => :public })
        @class.inactive :foo

        @field_foo = expect_and_create_field!('bar', 'foo', true, false, { :type => :normal, :visibility => :public, :storage => :foo })
        e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldStorageNameError) do
          @class.field 'bar', :storage => :foo
        end
        e.session_class.should be(@class)
        e.original_field_name.should == :foo
        e.new_field_name.should == :bar
        e.storage_name.should == 'foo'
        e.message.should match(/foo/i)
        e.message.should match(/bar/i)
      end
    end

    describe "retired fields" do
      it "should allow defining a retired field" do
        @field_foo = expect_and_create_field!(:foo, 'foo', false, true, { :type => :retired, :visibility => :public })
        @class.retired :foo

        @class._field_named(:foo).should be(@field_foo)
        @class._field_named('foo').should be(@field_foo)
        @class._field_with_storage_name(:foo).should be(@field_foo)
        @class._field_with_storage_name('foo').should be(@field_foo)
      end

      it "should conflict with a normal field" do
        @field_foo = expect_and_create_field!(:foo, 'foo', false, true, { :type => :retired, :visibility => :public })
        @class.retired :foo

        @field_foo = expect_and_create_field!('foo', 'bar', true, false, { :type => :normal, :visibility => :public, :storage => :bar })
        e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldNameError) do
          @class.field 'foo', :storage => :bar
        end
        e.session_class.should be(@class)
        e.field_name.should == :foo
        e.message.should match(/foo/i)
      end

      it "should raise if you try to define a field with the same storage name" do
        @field_foo = expect_and_create_field!(:foo, 'foo', false, true, { :type => :retired, :visibility => :public })
        @class.retired :foo

        @field_foo = expect_and_create_field!('bar', 'foo', true, false, { :type => :normal, :visibility => :public, :storage => :foo })
        e = capture_exception(ObjectifiedSessions::Errors::DuplicateFieldStorageNameError) do
          @class.field 'bar', :storage => :foo
        end
        e.session_class.should be(@class)
        e.original_field_name.should == :foo
        e.new_field_name.should == :bar
        e.storage_name.should == 'foo'
        e.message.should match(/foo/i)
        e.message.should match(/bar/i)
      end
    end
  end
end
