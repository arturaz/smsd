#!/usr/bin/env ruby

$:.push 'lib/'
require 'atphone.rb'

case ARGV.length
when 2
  number = ARGV[0]
  message = ARGV[1]
when 1
  number = ARGV[0]
  puts "Enter message for #{number}: "
  message = gets.chomp
when 0
  print "Enter number: "
  number = gets.chomp
  puts "Enter message for #{number}: "
  message = gets.chomp
end

# Connect to device
phone = ATPhone.new
begin
  phone.sms(number, message)
rescue ATPhone::Number::Invalid, ATPhone::SMS::Message::TooLong => e
  puts "Error! #{e}"
else
  puts "Sent."
end