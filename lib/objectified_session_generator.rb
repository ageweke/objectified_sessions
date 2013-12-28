require 'rails'
require 'rails/generators'
require 'fileutils'

# The ObjectifiedSessionGenerator is what gets invoked when you run <tt>rails generate objectified_session</tt>. It
# looks at whatever you have set as your ObjectifiedSessions class (which, of course, is overwhelmingly going to be the
# default at this point, since users likely won't have changed/customized it before they run this), and then plunks a
# file under lib/, in the right place, with an empty class, with nice comments in it.
class ObjectifiedSessionGenerator < Rails::Generators::Base
  def create_session_file
    class_name = ::ObjectifiedSessions.session_class

    # Check to see if this class exists in Ruby -- if so, we don't want to do anything; we don't want to rely on users
    # putting it under lib/, in the exact same place we would.
    if class_exists?(class_name)
      say "You appear to already have a class #{class_name.inspect}; doing nothing."
    else
      class_name = class_name.name if class_name.kind_of?(Class)
      class_path = class_name.underscore
      target_file = File.expand_path(File.join(Rails.root, 'lib', class_path + ".rb"))

      if (! File.exist?(target_file))
        # The success case -- write the class.
        write_objsession_class(target_file, class_name)
        say "Class #{class_name} created at #{target_file.inspect}."
      else
        # Somehow, we can't resolve the class, yet there's a file on disk in exactly the same place we want to put
        # one. Let the user know, and bail out.
        say %{You've configured ObjectifiedSessions to use class #{class_name} as your session class;
I can't currently load that class, but there's already a file at the following path:

#{target_file.inspect}

Please check that file to see what class it contains; if it's incorrect, remove it, and try again.}
      end
    end
  end

  private
  # Can we resolve a class (in Ruby) with the given name?
  def class_exists?(class_name)
    begin
      class_name.constantize
      true
    rescue NameError => ne
      false
    end
  end

  # Write a set of lines, specified as a multi-line string, to the given location, indented by the specified
  # number of spaces.
  def write_indented_lines(where, lines_string, indent_amount)
    lines_as_array = lines_string.split(/\r|\n|\r\n/)
    lines_as_array.each do |line|
      where << " " * indent_amount
      where.puts line
    end
  end

  # Write a template class to the given +target_file+, with the given +class_name+.
  #
  # If given a class that's nested under a module, this method goes out of its way to define nested modules (and
  # even indent properly!) surrounding the class. This is because lib/ is not under Rails' autoload path (any more),
  # and so it won't automatically generate modules mapped to file paths for us.
  def write_objsession_class(target_file, class_name)
    FileUtils.mkdir_p(File.dirname(target_file))

    class_components = [ ]
    while class_name =~ /^(.*?)::(.*)$/i
      class_components << $1
      class_name = $2
    end
    class_components << class_name

    File.open(target_file, "w") do |f|
      f.puts <<-EOF
# This is your ObjectifiedSession class. An instance of this class will automatically be available by calling
# #objsession from your controller, just like calling #session gets you (and will still get you) the normal session.
#
# See https://github.com/ageweke/objectified_sessions for more information.
EOF

      class_components[0..-2].each_with_index do |module_name, index|
        write_indented_lines(f, "module #{module_name}", index * 2)
      end

      write_indented_lines(f, "class #{class_name} < ::ObjectifiedSessions::Base", (class_components.length - 1) * 2)

      write_indented_lines(f, <<-EOF, class_components.length * 2)
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
EOF

      class_components.each_with_index do |module_name, index|
        write_indented_lines(f, "end", (class_components.length - (index + 1)) * 2)
      end
    end
  end
end
