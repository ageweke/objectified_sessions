require 'rails'
require 'rails/generators'

class ObjectifiedSessionGenerator < Rails::Generators::Base
  def create_session_file
    class_name = ::ObjectifiedSessions.session_class
    class_name = class_name.name if class_name.kind_of?(Class)

    class_path = class_name.underscore

    target_file = File.expand_path(File.join(Rails.root, 'lib', class_path + ".rb"))

    if (! File.exist?(target_file))
      write_objsession_class(target_file, class_name)
      say "Class #{class_name} created at #{target_file.inspect}."
    else
      if ::ObjectifiedSessions.session_class == ::ObjectifiedSessions::DEFAULT_OBJSESSION_CLASS_NAME
        say "You appear to already have an ObjectifiedSession class at #{target_file.inspect}."
      else
        say "You've configured ObjectifiedSessions to use class #{class_name} as your session class, and there's a file at #{target_file.inspect}. It looks like everything is good -- doing nothing."
      end
    end
  end

  private
  def write_objsession_class(target_file, class_name)
    File.open(target_file, "w") do |f|
      f.puts <<-EOF
# This is your ObjectifiedSession class. An instance of this class will automatically be available by calling
# #objsession from your controller, just like calling #session gets you (and will still get you) the normal session.
#
# See https://github.com/ageweke/objectified_sessions for more information.
class #{class_name} < ::ObjectifiedSessions::Base
  # FIELD DEFINITION
  # ==============================================================================================================

  # This defines a field named :foo; you can access it via self[:foo], self[:foo]=, and #foo and #foo=.
  # You can override these methods and call #super in them, and they'll work properly.
  # field :foo

  # This does the same, but the #foo reader and #foo= writer will be private.
  # field :foo, :visibility => :private

  # This creates a field named :foo, that's still accessed via self[:foo], self.foo, and so on, but which is actually
  # stored in the session object under just 'f'. You can use this to keep long names in your code but short names in
  # your precious session storage.
  # field :foo, :storage => :f

  # This creates an inactive field named :foo. Inactive fields can't be read or written in any way, but any data in
  # them will not be deleted, even if you set unknown_fields :delete.
  # inactive :foo

  # This creates a retired field named :foo. Retired fields don't really exist and any data in them will be deleted if
  # you set unknown_fields :delete, but you'll get an error if you try to also define a normal field with the same
  # name or storage setting. You can use retired fields to ensure you don't accidentally re-use old session fields.
  # retired :foo

  # CONFIGURATION
  # ==============================================================================================================

  # Sets the sub-key under which all data in your objectified session lives. This is useful if you already have a large
  # system with lots of session usage, and want to start using ObjectifiedSessions to manage new session use, but
  # partition it off completely from old, traditional session use.
  # prefix nil

  # Sets the default visibility of fields. The default is :public; if you set it to :private, you can still override it
  # on a field-by-field basis by saying :visibility => :public on those fields.
  # default_visibility :public

  # By default, ObjectifiedSessions will never delete session data unless you ask it to. However, if you set
  # unknown_fields :delete, then any unknown fields -- those you haven't mentioned in this class at all -- and any
  # retired fields will be automatically deleted from the session as soon as you touch it (_i.e._, the moment you
  # call #objsession in your controller). No matter what, however, nothing outside the prefix will ever be touched, if
  # a prefix is set.
  # unknown_fields :preserve
end
EOF
    end
  end
end
