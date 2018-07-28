require 'codebreaker'

RSpec.describe Codebreaker::Game do

  let(:game) { described_class.new('rspec', 'normal') }

  context 'invalid player_name/difficulty' do
    it 'initializes properly' do
      expect { described_class.new }.to raise_exception(ArgumentError)
      expect { described_class.new 'asd' }.to raise_exception(ArgumentError)
      (expect { described_class.new('asd', '') }
         .to raise_exception('invalid dificulty'))
      (expect { described_class.new('1', 'easy') }
         .to raise_exception('invalid name'))
    end
  end

  it 'can be played' do
    %i[play_again turn hint score save_score].each do |sym|
      expect(game).to respond_to(sym)
    end
  end

  it 'handles invalid guesses' do
    expect { game.turn '0000' }.to raise_exception('invalid digit')
    expect { game.turn %w[-1 0 3 4] }.to raise_exception('invalid digit')
    expect { game.turn [-1, 0, 3, ''] }.to raise_exception('invalid digit')
  end

  it 'actions after lose are idempotent' do
    allow(game).to receive(:save_score) { 'score saved' }
    code = game.instance_variable_get('@code').clone
    rand6 = game.method(:rand6)
    true_code = code.clone
    code[0] = code[0] > 3 ? (code[0] - 1) : (code[0] + 1)

    catch :outer do

      loop do
        state, = game.turn code
        if state == :lose
          10.times do
            expect(game.turn(rand6).first).to be == :lose
          end
          expect(game.turn(true_code).first).to be == :lose
          throw :outer
        end
      end
    end
  end

  it 'actions after win are idempotent' do
    code = game.instance_variable_get('@code').clone
    rand6 = game.method(:rand6)
    true_code = code.clone
    code[0] = code[0] > 3 ? (code[0] - 1) : (code[0] + 1)

    catch :outer do

      loop do
        game.turn true_code
        10.times do
          expect(game.turn(rand6).first).to be == :won
        end
        expect(game.turn(true_code).first).to be == :won
        throw :outer
      end
    end
  end

  it 'replies to hints' do
    expect(game).to respond_to(:hint)
  end

  it 'hint reduces score' do
    code = game.instance_variable_get('@code').clone
    g1, g2 = game.clone, game.clone
    g1.turn code
    g2.hint
    g2.turn code
    expect(g1.score > g2.score).to be_truthy
  end

  context 'won' do
    it 'saves score' do
      allow(game).to receive(:save_score) { 'score saved' }
      code = game.instance_variable_get('@code').clone
      game.turn code
      expect(game.save_score).to be == 'score saved'
    end
  end

  context 'lose' do
    it "don't saves score" do
      code = game.instance_variable_get('@code').clone
      code[0] = code[0] > 3 ? (code[0] - 1) : (code[0] + 1)
      game.turn code
      expect { game.save_score }.to raise_exception('win first')
    end
  end
end
