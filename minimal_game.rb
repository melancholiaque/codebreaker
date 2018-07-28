require'codebreaker'

pgets = ->(msg) { (puts msg) || gets.rstrip }
name = -> { pgets['chose name'] }
diff = -> { pgets['chose difficulty'] }

G = Codebreaker::Game.new(name[], diff[])

loop do
  guess = gets.rstrip.split('')
  (puts G.hint) || next if guess == %w[h i n t]
  ret, match = G.turn guess
  puts match
  break (puts "won: #{G.score}") || G.save_score if ret == :won
  (puts 'lose') || G.play_again(diff[]) if ret == :lose
end
