#!/usr/bin/env ruby
require 'commands/helper.rb'
require 'commands/sqlhelper.rb'

help("Shows the number of games won. Usage:" +
     " !won <nick> [<number of wins to skip>]")

def parse_args
  words = ARGV[2].split(' ')[ 1..-1 ]
  return [ ARGV[1], 0, [] ] if !words || words.empty?

  if words[0] =~ /^(?:[a-zA-Z@]\w+|\*|[.])$/
    nick = words.slice!(0).sub(/^@/, '')
  end

  num = 0
  words.size.times do |i|
    if words[i] =~ /^[+-]?\d+$/
      num = words.slice!(i).to_i
      break
    end
  end

  nick = nil if nick == '.'

  nick ||= ARGV[1]
  [ nick, num, words ]
end

def times(n)
  n == 1 ? "once"  :
  n == 2 ? "twice" :
           "#{n} times"
end

nick, num, trail_select = parse_args

if not num or num < 0
  puts "Bad index: #{num}"
  exit 1
end

games = nil
begin
  desc = nick
  game = extract_game_type(trail_select)
  if num == 0
    q, game_count_query = GameContext.with_game(game) do
      [sql_define_query(nick, -1,
                        trail_select + ["ktyp=winning"],
                        nil).reverse,
       sql_define_query(nick, -1, trail_select, nil)]
    end
    count = sql_count_rows_matching(game_count_query)
    desc = game_count_query.argstr
  else
    if nick == '*'
      puts "Cannot combine * with win-skip count."
      exit 0
    end
    q = GameContext.with_game(game) do
      sql_define_query(nick, -1, trail_select, nil).reverse
    end
    desc = q.argstr
    count = 0
  end
  wins = []

  whash  = Hash.new(0)
  nwins  = 0
  allwins = 0
  offset = num
  first  = 0
  lastwin = ''
  nfinalwin = 0
  finalwin = ''

  name = nick
  sql_each_row_matching(q) do |row|
    g = row_to_fieldmap(row)
    count += 1 if num != 0

    name = g['name'] unless name == '*'
    if g['ktyp'] == 'winning'
      allwins += 1
      offset -= 1
      nfinalwin = count
      finalwin = g['char']
      if offset == 0
        first = count
	lastwin = g['char']
      end
      if offset < 0
        nwins += 1
        wins << g['char']
        whash[g['char']] += 1
      end
    end
  end

  if count == 0
    printf("No games for #{desc}.\n")
  else
    if nwins == 0 then
      if (num < allwins || allwins == 0) && first == 0 then
        puts "#{desc} has not won in #{count} games."
      else
        puts "#{desc} has not won in #{count - nfinalwin} games" +
          " since their #{finalwin}" +
          " (win ##{allwins})."
      end
    else
      if num == 0 then
        wins = whash.to_a.
          sort { |a,b| a.last == b.last ? a.first <=> b.first :
          b.last <=> a.last }.
          map { |a,b| "#{b}x#{a}" }.
          join(' ')
        puts "#{desc} has won #{times(nwins)} in #{count} games " +
          "(#{sprintf('%0.2f%%', nwins * 100.0 / count)}): #{wins}"
      else
        wins = wins.join(', ')
        ngames = count - first
        perc = sprintf('%0.2f%%', nwins * 100.0 / ngames)
        puts "#{desc} has won #{times(nwins)} in #{count - first} " +
          "games (#{perc}) " +
          "since their #{lastwin} (win ##{num}): " +
          wins
      end
    end
  end
rescue
  puts $!
  raise
  exit 1
end
