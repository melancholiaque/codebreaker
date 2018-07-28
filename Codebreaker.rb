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
        if game_store[name]
          game_store[name].play_again(difficulty)
        else
          args = name, difficulty, score_file
          game_store[name] = Codebreaker::Game.new(*args)
        end
        ok 'ready to play'
      end
    rescue RuntimeError => e
      not_ok e.message
    end
  end

  post '/start_game/:diff' do |diff|
    login_required
    new_game diff
  end

  post '/turn/:guess' do |guess|
    login_required
    with_current_game do |game|
      state, match = game.turn(guess.to_s)
      game.save_score if state == :won
      ok state: state, match: match
    end
  end

  get '/current_state' do
    login_required
    with_current_game do |game|
      ok match: game.current_match.join(''), guess: game.guess
    end
  end

  get '/score' do
    login_required
    with_current_game do |game|
      ok game.score
    end
  end

  get '/scores' do
    ok (File.open(score_file, 'r', &:read) rescue not_ok 'no scores yet')
  end

  get '/hint' do
    login_required
    ok with_current_game(&:hint)
  end

  post '/begin' do
    name, pass = body['name'], body['pass']
    if invalid(name, pass)
      not_ok 'invalid name and/or pass'
    elsif (name1 = login_manager.register(name, pass))
      session[:name] = name1
      ok 'signed up'
    elsif (name2 = login_manager.verify(name, pass))
      session[:name] = name2
      ok 'signed in'
    else
      not_ok 'such user already exists'
    end
  end
end
