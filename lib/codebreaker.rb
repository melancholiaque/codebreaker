# coding: utf-8

require_relative 'ArrayExtensions'

module Codebreaker
  # codebreaker
  class Game
    using ArrayExtensions
    attr_reader :current_match, :guess, :tries, :difficulty, :state, :score

    DIFFICULTY = {
      :baby => { tries: Float::INFINITY, score_multiplier: 0},
      :easy => { tries: 10, score_multiplier: 1 },
      :normal => { tries: 8, score_multiplier: 2 },
      :hard => { tries: 5, score_multiplier: 3 },
      :very_hard => { tries: 3, score_multiplier: 4 },
      :nightmare => { tries: 1, score_multiplier: 5 }
    }.freeze

    def initialize(player_name, difficulty, file = 'codebreaker_score.txt')
      raise 'invalid name' unless player_name =~ /^[A-Za-z]{3,20}$/
      @player_name = player_name
      initialize_game(difficulty.to_s.rstrip, file)
    end

    def play_again(difficulty = nil, file = nil)
      initialize_game(
        difficulty&.to_s&.rstrip || @difficulty,
        file || @score_file_path
      )
    end

    def turn(guess)
      unless [:won, :lose].include? @state
        submit_guess(guess)
        calculate_result
        change_state
      end
      [@state, @current_match.join]
    end

    def hint
      unless @hint_taken
        @hint_taken = true
        @coof = [0, @coof-1].max
        matches = @guess_history.transpose.zip(@code).map { |seq, dig| seq.include? dig }
        hints = matches.zip((0..3)).select { |match, position| !match}.map(&:last)
        return nil if hints.count == 1
        val = hints.sample
        '    '.tap { |s| s[val] = @code[val].to_s }
      end
    end

    def score
      return @score = 0 unless @state == :won
      @score = @match_history.flatten.count('+')
      @score += @match_history.flatten.count('-') * 0.5
      @score /= (@tries + 1) * 4
      @score *= @coof * 100
      @score = @score.floor
    end

    def save_score(file = @score_file_path)
      raise 'win first' if @state != :won
      raise 'no score file given' unless file
      unless @score_saved
        File.open(file, 'a') do |file|
          file.puts("#{@player_name}:#{@difficulty}:#{score}")
        end
        @score_saved = true
      end
    end

    private

    def submit_guess(guess)
      guess = guess.rstrip.split('') if guess.is_a? String
      guess = guess.map(&:to_i) if guess.any? { |c| c.is_a? String }
      @tries -= 1
      raise 'max tries exceeded' if @tries < 0
      raise 'guess length ≠ 4' if guess.length != 4
      raise 'invalid digit' unless guess.all? { |c| (1..6).cover?(c.to_i) }
      @guess_history << (@guess = guess)
    end

    def initialize_game(difficulty, file = nil)
      difficulty = difficulty&.to_sym
      raise 'invalid difficulty' unless DIFFICULTY.include? difficulty
      @difficulty = difficulty
      @code, @state, @guess = rand6, :next, nil
      @unmatched_exactly = nil
      @max_tries = DIFFICULTY[difficulty][:tries]
      @tries = DIFFICULTY[difficulty][:tries]
      @coof = DIFFICULTY[difficulty][:score_multiplier]
      @match_history, @guess_history = [], []
      @score, @score_saved = 0, false
      @hint_taken = false
      @score_file_path = file&.is_a?(File) ? file.path : file
    end

    def rand6
      (1..4).map { rand(1..6) }
    end

    def exact_match
      icode = @code.enumerate
      iguess = @guess.enumerate
      exact, no_exact = icode.zip(iguess).partition { |(a, _), (c, _)| a == c }
      @unmatched_exactly = no_exact.transpose
      exact.map(&:first).map(&:last)
    end

    def number_match
      return @number_match_indices = [] if @unmatched_exactly.empty?
      fst, snd = @unmatched_exactly
      fst.map!(&:first)
      partial = snd.select do |v, _|
        fst.include?(v) && fst.delete_one(v)
      end
      partial.map(&:second)
    end

    def calculate_result
      @current_match = [' '] * 4
      exact_match&.map { |i| @current_match[i] = '+' }
      number_match&.map { |i| @current_match[i] = '-' }
      @current_match.tap { |s| @match_history << s}
    end

    def change_state
      if @tries <= 0 and @current_match != ['+'] * 4
        @state = :lose
      elsif @current_match == ['+'] * 4
        @state = :won
      else
        @state = :next
      end
    end
  end
end