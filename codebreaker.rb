require_relative 'foo'
require 'codebreaker'
require 'pstore'

Foo.define do

  default_type :json

  set game_store: PStore.new('codebreaker_games.pstore')
  set login_manager: Foo::AuthManager.new('test.db')
  set score_file: 'codebreaker_score.txt'

  set(:ok) { |content, **kw| { status: :ok, content: content || kw } }
  set(:not_ok) { |msg| { status: :fail, msg: msg } }
  set(:name) { session[:name] }
  set(:invalid) { |name, pass| !([name, pass].all? { |c| /^\w{3,20}$/ =~ c }) }

  set :with_current_game do |&block|
    begin
      game_store.transaction do
        game = game_store[name]
        game ? block[game] : not_ok('start game first')
      end
    rescue RuntimeError => e
      not_ok e.message
    end
  end

  set :new_game do |difficulty|
    begin
      game_store.transaction do
        game = game_store[name]
        if game
          game.play_again(difficulty)
        else
          args = name, difficulty, score_file
          game_store[name] = Codebreaker::Game.new(*args)
        end
        p game_store[name].instance_variable_get("@code".to_sym)
        ok 'ready to play'
      end
    rescue RuntimeError => e
      not_ok e.message
    end
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

  get '/score' do
    with_current_game do |game|
      ok game.score
    end
  end

  get '/scores' do
    File.open(score_file, 'r', &:read) rescue not_ok 'no scores yet'
  end

  get '/hint' do
    login_required
    ok with_current_game(&:hint)
  end

  get '/sign_up/:name/:pass' do |name, pass|
    if invalid(name, pass)
      not_ok 'invalid name and/or pass'
    elsif (name = login_manager.register(name, pass))
      session[:name] = name
      ok 'registered'
    else
      not_ok 'such user already exists'
    end
  end

  get '/sign_in/:name/:pass' do |name, pass|
    if (name = login_manager.verify(name, pass))
      session[:name] = name
      ok 'logged in'
    else
      not_ok 'invalid creditnails'
    end
  end
end
