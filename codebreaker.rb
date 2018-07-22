# coding: utf-8
require_relative 'foo'
require 'codebreaker'
require 'pstore'

Foo.define do

  default_type :json
  set game_store: PStore.new('codebreaker_games.pstore')
  set login_manager: Foo::AuthManager.new('test')
  set(:ok) { |content, **kw| { status: :ok, content: content || kw } }
  set(:not_ok) { |msg| { status: :fail, msg: msg } }

  set :wrap do |&block|
    begin
      block.yield
    rescue RuntimeError => e
      not_ok e.message
    end
  end

  set :with_current_game do |&block|
    game_store.transaction do
      block[game_store[session[:name]]]
    end
  end

  set :new_game do |difficulty|
    wrap do
      with_current_game do |game|
        if game
          game.play_again(difficulty)
        else
          game_store[session[:name]] = Codebreaker::Game.new(
            session[:name],
            difficulty
          )
        end
        ok 'ready to play'
      end
    end
  end

  get '/', type: :text do
    <<-EOS
    welcome to codebreaker version of the game
    API schema:
    /sign_in/:name/:pass
    /sign_up/:name/:pass
    /start_game/:difficulty
    EOS
  end

  get '/start_game/:diff' do |diff|
    login_required
    new_game diff
  end

  get '/turn/:guess' do |guess|
    login_required
    with_current_game do |game|
      state, match = game.turn(guess.to_s)
      game.save_score if state == :won
      ok state: state, match: match
    end
  end

  get '/sign_in/:name/:pass' do |name, pass|
    if (name = login_manager.register(name, pass))
      session[:name] = name
      ok 'registered'
    else
      not_ok 'such user already exists'
    end
  end

  get '/sign_up/:name/:pass' do |name, pass|
    if (name = login_manager.verify(name, pass))
      session[:name] = name
      ok 'logged in'
    else
      not_ok 'invalid creditnails'
    end
  end
end
