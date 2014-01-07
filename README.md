# ObjectifiedSessions

Encapsulate and carefully manage access to your Rails session by modeling it as an object that you add fields and
methods to, rather than a free-for-all Hash.

By default, Rails models your session as a Hash. While this makes it really easy to use, it also makes it really easy
to make a mess: as your app grows, you have to search the entire codebase for usage of `session` (a pretty common
word that's certain to be used in many irrelevant ways, as well) to figure out how it's being used. It's easy for it
to grow almost without bound, and hard to keep a team of developers in sync about how it's being used. Further, the
otherwise-extremely-nice
[CookieStore](http://api.rubyonrails.org/classes/ActionDispatch/Session/CookieStore.html) exacerbates these problems
&mdash; because you no longer have the power to change the sessions that are now stored in users' browsers, as cookies.

Using ObjectifiedSessions:

* You can define exactly what session fields can be used, and control access to them through accessor methods that you
  can override to do anything you want. You can validate stored data, apply defaults when returning data, and so on.
  You can ensure that data is carefully filtered to store it in the most-compact possible format, and unpack it before
  returning it. (For example, you can store values as simple integers in the session to save space, but read and write
  them using clear, easy symbols from client code.)
* You can eliminate the tension between using long, descriptive, maintainable names for session data &mdash;
  and hence wasting very valuable session storage space &mdash; and using compact, unmaintainable names to save
  space is gone. _Storage aliases_ let you access data using a long, descriptive name, while ObjectifiedSessions
  automatically stores it in the session using a short, compact alias.
* You can automatically clean up old, no-longer-used session data: if requested, ObjectifiedSessions will automatically
  delete data from the session that is no longer being used. (This is switched off by default, for obvious reasons.)
* _Inactive_ fields let you preserve data that you want to make sure you aren't currently using, but which you don't
  want deleted forever.
* _Retired_ fields let you keep track, forever, of session fields that you used to use &mdash; and, with the
  CookieStore, may forever exist in inbound sessions &mdash; so you don't ever accidentally re-use the same name for
  different session data, causing potentially catastrophic effects.
* Explicit field definition lets you immediately see exactly what data you're using.
* There's absolutely no additional restriction on what you can store, vis-à-vis Rails' normal session support.

And, best of all, you can migrate to ObjectifiedSessions completely incrementally; it interoperates perfectly with
traditional session-handling code. You can migrate call site by call site, at your own pace; there's no need to
migrate all at once, or even migrate all code for a given session key all at once.

Current build status: ![Current Build Status](https://api.travis-ci.org/ageweke/objectified_sessions.png?branch=master)

## Installation

Add this line to your application's Gemfile:

    gem 'objectified_sessions'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install objectified_sessions

## Usage

#### Quick Start

Simply installing the Gem won't break anything. However, before the `#objsession` call from inside a controller will
work, you need to create the class that implements your session. The simplest way to do this is by running
`rails generate objectified_session`; this will write a file to `lib/objsession.rb` that defines an empty
objectified session.

To start storing data, you need to define one or more fields on your session:

    class Objsession < ::ObjectifiedSessions::Base
      field :last_login
      field :user_id
    end

...and now you can use it from controllers (or anywhere else, if you pass around the `#objsession` object) via:

    objsession.last_login = Time.now
    User.find(objsession.user_id)

...and so on.

The fields you define map exactly to traditional session fields &mdash; given the above, `objsession.user_id` and
`session[:user_id]` will _always_ return exactly the same value, and assigning one will assign the other. In other
words, ObjectifiedSessions is not doing anything magical or scary to your session; rather, it's simply giving you a
very clean, maintainable interface on top of the `session` you already know and love. You can assign any value to a
field that is supported by Rails' traditional `session`, from an integer to an array of disparate Objects, or anything
else you want.

Already, you have a single point where all known session fields are defined (assuming you're not using any old-style
calls to `#session`). Read on for more benefits.

#### Adding Methods

You can, of course, define methods on this class that do anything you want &mdash; write fields, read fields, or simply
answer questions:

    class Objsession < ::ObjectifiedSessions::Base
      field :last_login
      field :user_id

      def logged_in!(user)
        self.last_login = Time.now unless self.last_login >= 5.minutes.ago
        self.user_id = user.id
      end

      def logged_in_today?
        self.last_login >= Time.now.at_midnight
      end
    end

...and then, in your controllers, you can say:

    def login!
      my_user = User.where(:username => params[:username])
      if my_user.password_matches?(params[:password])
        objsession.logged_in!(my_user)
      end
    end

    def some_other_action
      @logged_in_today = objsession.logged_in_today?
    end

#### Private Methods

If you'd like to ensure your fields aren't modified outside the class, you can make them private:

    class Objsession < ::ObjectifiedSessions::Base
      field :last_login, :visibility => :private
      field :user_id, :visibility => :private

      def logged_in!(user)
        self.last_login = Time.now unless self.last_login >= 5.minutes.ago
        self.user_id = user.id
      end

      def logged_in_today?
        self.last_login >= Time.now.at_midnight
      end
    end

Now, if someone says `objsession.last_login = Time.now` in a controller, or `objsession.user_id`,
they'll get a `NoMethodError`. Like all Ruby code, you can, of course, use `#send` to work around this if you need to.

If you want all methods to be private, you can set the default visibility, and then set fields' accessors to be public
if you want them to be:

    class Objsession < ::ObjectifiedSessions::Base
      default_visibility :private

      field :last_login
      field :user_id
      field :nickname, :visibility => :public
    end

#### Overriding methods, Hash-style access, and `super`

You can override accessor methods; `super` will work properly, and you can also access properties using Hash-style
access (which is always private, unless you use `public :[], :[]=` to make it public):

    class Objsession < ::ObjectifiedSessions::Base
      field :user_type

      def user_type=(new_type)
        unless [ :guest, :normal, :admin ].include?(new_type)
          raise ArgumentError, "Invalid user type: #{new_type}"
        end

        super(new_type)
      end

      def user_type
        super || :normal
      end

      def is_admin?
        self[:user_type] == :admin
      end
    end

#### Storage Aliasing

Unlike database columns, the names of session keys are embedded in _every single instance_ of stored session data.
You're often stuck in the tension between wanting to use long names to make your code readable, and short names to
save precious session-storage space.

Enter storage aliases:

    class Objsession < ::ObjectifiedSessions::Base
      field :custom_background_color, :storage => :cbc
    end

Now, your controller looks like:

    if objsession.custom_background_color
      ...
    end

...while you're now using three, rather than 23, bytes of storage space for the key for that field.

**IMPORTANT**: Changing the storage alias for a field, or setting one, will cause _all existing data for that field
to disappear_. (Hopefully this is obvious; this is because ObjectifiedSessions will now be looking under a different
key for that data.) It is, however, safe to do the reverse, by renaming a field and setting its storage alias to
be its old name.

#### Retiring Fields

Let's say you (probably wisely) stop supporting custom background colors, and remove that field. So far, so good.

Time passes, and now you introduce a session field saying whether or not the user has behaved consistently on your
site in some way &mdash; a "consistent behavior check". You add an appropriate session field:

    class Objsession < ::ObjectifiedSessions::Base
      field :consistent_behavior_check, :storage => :cbc
    end

Uh-oh. Now you're going to start interpreting whatever data was there for your old `custom_background_color` field
as `consistent_behavior_check` data, and bad, bad things may happen. (Using a CookieStore often makes this problem
worse, since sessions can last an arbitrarily long time unless you set a cookie timeout &mdash; which has other
disadvantages.)

To avoid this, when you remove a field, _don't_ remove it entirely from the session class; instead, use the `retired`
keyword instead of `field`:

    class Objsession < ::ObjectifiedSessions::Base
      retired :custom_background_color, :storage => :cbc
    end

Now, when you add the new `consistent_behavior_check` field...

    class Objsession < ::ObjectifiedSessions::Base
      field :consistent_behavior_check, :storage => :cbc

      retired :custom_background_color, :storage => :cbc
    end

...you'll get an error:

    ObjectifiedSessions::Errors::DuplicateFieldStorageNameError (Class Objsession already has a field, :custom_background_color, with storage name "cbc"; you can't define field :consistent_behavior_check with that same storage name.)

#### Cleaning Up Unused Fields

Particularly if you're using the CookieStore to store session data, values for fields you no longer use may still be
sitting in the session, taking up valuable space. You can tell ObjectifiedSessions to automatically remove any data
that isn't defined as a `field`:

    class Objsession < ::ObjectifiedSessions::Base
      unknown_fields :delete

      field :user_id
      field :last_login
      ...
    end

Now, if, for example, a session is found that has a field `cbc` set, ObjectifiedSessions will automatically delete that
key from the session.

**Important Notes** &mdash; **BEFORE** you use this feature, read these:

1. **You can LOSE DATA if you combine this with traditional session access**. If you have code that reads or
    writes `session[:foo]`, and you have no `field :foo` declared in your `objsession`, then ObjectifiedSessions
    will go around deleting field `:foo` from your session, breaking your code in horrible, horrible ways.
    Be **absolutely certain** that one of the following is true: (a) you're only using `objsession` to access session
    data, (b) you've defined a `field` in your `objsession` for any data that your traditional session code touches,
    or (c) use a `prefix`, as discussed below.
2. **Be aware of Gems or plugins that may use the session!** These may be storing data in the session that you're not
    aware of, and that you won't discover by searching your codebase. To be safe, examine actual, real-world session
    data and the keys that it's using. (Iterating over all sessions in `memcached`, for example, or tracking keys
    used in all cookie-based sessions over the course of a whole day, can be very valuable, too.)
3. **Retired fields ARE deleted**. This is because by retiring a field, you're saying, "I will never use this data
    again, but keep an eye on it for me to make sure I don't accidentally re-use that key". If you want to use
    `unknown_fields :delete` and don't want this behavior, use the `inactive` keyword instead of `retired`; it
    behaves identically (you can't access the data, and you can't define a field that conflicts), but it won't delete
    the data for that key.
4. **Be extremely careful when removing or retiring fields**. This goes without saying, but, once you've deleted that
    data, it's gone forever. If you have any doubt, use `inactive` until you're certain.
5. Deletion doesn't happen unless you actually instantiate the ObjectifiedSession, which only happens when you call
    `objsession` from inside a controller. This is intentional &mdash; we don't want ObjectifiedSessions to add any
    overhead whatsoever until you need it. If you want to ensure that this happens on every request, simply add a
    `before_filter` that calls `objsession`. (You don't need to read or write any fields, so simply calling
    `objsession` is sufficient.)

#### Partitioning Off the Session (Using a Prefix)

In certain cases, you may want ObjectifiedSessions to manage (and keep tidy) new session code, but want to make sure
it cannot conflict at all with existing session data. In this case, you can set a _prefix_; this is a key under which
all session data managed by ObjectifiedSessions will be stored.

For example &mdash; without the prefix:

    class Objsession < ::ObjectifiedSessions::Base
      field :user_id
      field :last_login
    end

    objsession.user_id = 123
    objsession.last_login = Time.now

    session[:user_id]     # => 123
    session[:last_login]  # => Thu Dec 26 19:35:55 -0600 2013

But with the prefix:

    class Objsession < ::ObjectifiedSessions::Base
      prefix :p

      field :user_id
      field :last_login
    end

    objsession.user_id = 123
    objsession.last_login = Time.now

    session[:user_id]         # => nil
    session[:last_login]      # => nil
    session[:p]               # => { 'user_id' => 123, 'last_login' => Thu Dec 26 19:35:55 -0600 2013 }
    session[:p]['user_id']    # => 123
    session[:p]['last_login'] # Thu Dec 26 19:35:55 -0600 2013

Think carefully before you use this feature. In many cases, it is simply not necessary; ObjectifiedSessions
interoperates just fine with traditional session-handling code. The only case where it's really required is if you have
a very large base of code using the traditional `session` object, and you want to introduce ObjectifiedSessions bit
by bit, _and_ use `unknown_fields :delete`. This should be a very rare case, however.

**Changing the prefix will make all your existing data disappear!** Hopefully this is obvious, but setting the
prefix makes ObjectifiedSessions look in a different place when reading or writing data; this means that changing it
will cause all existing data to effectively disappear. Think carefully, choose whether to use a prefix or not, and then
leave it alone.

#### Strings vs. Symbols

ObjectifiedSessions acts as a
[HashWithIndifferentAccess](http://api.rubyonrails.org/classes/ActiveSupport/HashWithIndifferentAccess.html)
internally, so you can use either a String or a Symbol to access a given field when using Hash syntax, and you'll get
the exact same result. It always talks to the Session using Strings, but this should be irrelevant in almost all
cases.

(The only case where this actually matters is if you use a prefix; data stored under the prefix will be a Hash with
Strings as keys, not Symbols.)

#### Changing the Objectified-Session Class, and Session Loading

If, for some reason, you want the class you use for your objectified session to be called something other than
`Objsession`, you can change it like so in `config/application.rb`:

    ObjectifiedSessions.session_class = :MyObjectifiedSession
    # or ObjectifiedSessions.session_class = 'MyObjectifiedSession'
    # or ObjectifiedSessions.session_class = MyObjectifiedSession
    #   ...i.e., you can set a Class object itself

If you use either the String or Symbol form, then ObjectifiedSessions will attempt to `require` the corresponding
file before resolving the class (but won't fail if that doesn't work &mdash; only if it still can't resolve the
class afterwards). This means that the class you use does need to either already be loaded, or the file it's in needs
to be named correctly and on one of Rails' `load_paths`.

#### Debugging and Other Tools

You can call #fields on the objectified-session object to get back an Array of Symbols, listing the fields that _can_
be set on the session. You can call #fields on the objectified-session object to get back an Array of Symbols, listing
the fields that _have_ something set (besides _nil_ &mdash; note, in this case, that `false` is distinct from `nil`)
at present.

Calling `#to_s` or `#inspect` (which produce the same result) on the objectified session will produce a nice string
containing, in alphabetical order, all data that's set on the session. Long data is abbreviated at forty characters;
passing an argument of `false` to either of these methods will remove such abbreivation.

#### Migrating To ObjectifiedSessions

If you have an existing application and want to migrate to ObjectifiedSessions bit by bit, here's how I'd do it:

1. Install the gem.
2. Run the generator (`rails generate objectified_session`).
3. Find some traditional session-handling code.
4. Make sure there's a `field` declared in the ObjectifiedSession for whatever key the traditional session-handling
   code is using.
5. Define methods on the ObjectifiedSession, if appropriate, to add appropriate functionality (value checking,
   question-answering, and so on) around this field.
6. Change the traditional session-handling code to use `objsession` and the new methods.
7. Test, commit, and deploy.
8. Repeat steps 3-7.

The key point is that you don't have to migrate to ObjectifiedSessions all at once, or even all code that uses a single
session field all at once.

Once you're done, and you're _completely_ certain you've eliminated all use of traditional session code (and checked
for Gems, plugins, or other code that may be using the session without your knowledge), you can set
`unknown_fields :delete`, if you'd like.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

### Running Specs

ObjectifiedSessions is very thoroughly tested, including both system specs (that test the entire system at once) and
unit specs (that test each class individually).

To run these specs:

1. `cd objectified_sessions` (the root of the gem).
2. `bundle install`
3. `bundle exec rspec spec` will run all specs. (Or just `rake`.)
