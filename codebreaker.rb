require_relative 'foo'
require 'codebreaker'

def not_ok(msg)
  { status: :fail, msg: msg }
end

def ok(content)
  { status: :ok, content: content }
end

Foo.define do

  games = {}

  get '/', type: :json do
    'hello'
  end

  get '/register/:name/:pass', type: :json do |name, pass|
    if (name = login_manager.register(name, pass))
      session[:name] = name
      ok 'successfully registered'
    else
      not_ok 'such user already exists'
    end
  end

  get '/verify/:name/:pass', type: :json do |name, pass|
    if (name = login_manager.verify(name, pass))
      session[:name] = name
      ok 'logged in'
    else
      not_ok 'wrong creditnails'
    end
  end
end
