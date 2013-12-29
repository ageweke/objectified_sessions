require 'objectified_sessions'

describe ObjectifiedSessions::Errors do
  before :each do
    @session_class = double("session_class")
    allow(@session_class).to receive(:name).with().and_return("scname")
    allow(@session_class).to receive(:to_s).with().and_return("scto_s")
    allow(@session_class).to receive(:inspect).with().and_return("scinspect")
    allow(@session_class).to receive(:accessible_field_names).with().and_return([ :foo, :bar, :baz ])

    @field_name = double("field_name")
    allow(@field_name).to receive(:to_s).with().and_return("fnto_s")
    allow(@field_name).to receive(:inspect).with().and_return("fninspect")

    @field_name_2 = double("field_name_2")
    allow(@field_name_2).to receive(:to_s).with().and_return("fn2to_s")
    allow(@field_name_2).to receive(:inspect).with().and_return("fn2inspect")

    @storage_name = double("storage_name")
    allow(@storage_name).to receive(:to_s).with().and_return("snto_s")
    allow(@storage_name).to receive(:inspect).with().and_return("sninspect")
  end

  it "should inherit Base from StandardError" do
    ObjectifiedSessions::Errors::Base.new("foo").kind_of?(StandardError).should be
  end

  it "should inherit CannotCreateSessionError from Base" do
    ObjectifiedSessions::Errors::CannotCreateSessionError.new("foo").kind_of?(ObjectifiedSessions::Errors::Base).should be
  end

  it "should inherit NoSuchFieldError from Base, and give a good message" do
    instance = ObjectifiedSessions::Errors::NoSuchFieldError.new(@session_class, @field_name)

    instance.kind_of?(ObjectifiedSessions::Errors::Base).should be

    instance.session_class.should be(@session_class)
    instance.field_name.should be(@field_name)
    instance.accessible_field_names.should == [ :foo, :bar, :baz ]

    instance.message.should match(/scname/i)
    instance.message.should match(/fninspect/i)
    instance.message.should match(/foo/i)
    instance.message.should match(/bar/i)
    instance.message.should match(/baz/i)
  end

  it "should inherit DuplicateFieldNameError from Base, and give a good message" do
    instance = ObjectifiedSessions::Errors::DuplicateFieldNameError.new(@session_class, @field_name)

    instance.kind_of?(ObjectifiedSessions::Errors::Base).should be

    instance.session_class.should be(@session_class)
    instance.field_name.should be(@field_name)

    instance.message.should match(/scname/i)
    instance.message.should match(/fninspect/i)
  end

  it "should inherit DuplicateFieldStorageNameError from Base, and give a good message" do
    instance = ObjectifiedSessions::Errors::DuplicateFieldStorageNameError.new(@session_class, @field_name, @field_name_2, @storage_name)

    instance.kind_of?(ObjectifiedSessions::Errors::Base).should be

    instance.session_class.should be(@session_class)
    instance.original_field_name.should be(@field_name)
    instance.new_field_name.should be(@field_name_2)
    instance.storage_name.should be(@storage_name)

    instance.message.should match(/scname/i)
    instance.message.should match(/fninspect/i)
    instance.message.should match(/fn2inspect/i)
    instance.message.should match(/sninspect/i)
  end
end
