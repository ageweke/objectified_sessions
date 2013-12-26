# ObjectifiedSessions

Encapsulate and carefully manage access to your Rails session by modeling it as an object that you add fields and
methods to, rather than a free-for-all Hash.

By default, Rails models your session as a Hash. While this makes it really easy to use, it also makes it really easy
to make a mess: as your app grows, you have to search the entire codebase for usage of `session` (a pretty common
word) to figure out how it's being used. It's easy for it to grow almost without bound, and hard to keep a team of
developers in sync about how it's being used. Further, the otherwise-extremely-nice
[CookieStore](http://api.rubyonrails.org/classes/ActionDispatch/Session/CookieStore.html) exacerbates these problems
&mdash; because you no longer have the power to change the sessions that are now stored in users' browsers, as cookies.

You can integrate ObjectifiedSessions into your existing application seamlessly; by default, all its data is stored
underneath a single (short) key in your existing sessions, so it won't conflict with existing code. However, you can
also have it manage the entire session directly, if you want.

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

## Installation

Add this line to your application's Gemfile:

    gem 'objectified_sessions'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install objectified_sessions

## Usage

#### Quick Start

Simply installing the Gem won't break anything. However, before the #objsession call from inside a controller will
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

Already, you have a single point where all known session fields are defined (assuming you're not using any old-style
calls to `#session`.)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
