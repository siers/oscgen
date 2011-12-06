#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# self(44aa 78ea 455d), /06.12.2011./
# Oscillation generator.
# http://en.wikipedia.org/wiki/Piano_key_frequencies

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

class Fixnum
  def octave
    self * 12
  end

  alias octaves octave
end

class OscillationGenerator
  @@generators = {}

  def initialize(&block)
    @notes = {
      :do => 40,
      :re => 42,
      :mi => 44,
      :fa => 45,
      :sol => 47,
      :la => 49,
      :si => 51,
      :bemmole => -1,
      :sharp => 1
    }
    @waves = []
    @rate = nil
    @pipe = $>

    instance_eval &block
    generate
  end

  def math(function, n) # A convenient wrapper.
    Math.send(function, n * Math::PI / 180)
  end
  def note(*descriptions)
    number = 0
    descriptions.each do |descr|
      case descr
        when Symbol
          begin
            if number == 0
              number = @notes[descr]
            else
              number += @notes[descr] # use only bemmole/sharp here
            end
          rescue TypeError
            list = @notes.map {|note| ":#{ note[0].to_s }" }.join(', ')
            whine "Unknown symbol(:#{descr}), choose one of these:\n\t#{ list }"
          end
        when Fixnum
          number += descr
      end
    end

    frequency = 440 * 2 ** ((number - 49.0) / 12)
  end

  def wave(opts)
    @waves << {:frequency => 8000, :counter => 0, :offset => 0}.merge(opts)
  end

  # Defines a generator.
  def define(name, &block)
    @@generators[name] = block
  end

  # Initializes wave variables.
  def setup_rates
    @waves.map! do |wave|
      wave[:counter]     = 0
      wave[:period]      = @rate / wave[:frequency]
      wave[:coefficient] = 360.0 * wave[:frequency] / @rate
      # perc = i / rate
      # sin_value = perc * 360
      wave
    end
  end

  def mix voltages
    [0, [255, voltages.inject(0) { |s, i| s + i } / @wave_count + 128].min].max
  end

  # Runs generator blocks, mixes their output, outputs to stdout.
  def generate
    whine 'Rate not set.' unless @rate
    setup_rates
    @wave_count = @waves.length

    loop do
      voltages = []

      @waves.each_with_index do |wave, i|
        # t ∈ [0; 360)
        t = wave[:counter] * wave[:coefficient] + wave[:offset]
        voltage = @@generators[wave[:type]].call(t) * 128
        voltages << voltage
        @waves[i][:counter] = (wave[:counter] + 1) % wave[:period]
      end

      voltage = mix(voltages)
      @pipe.write(voltage.to_i.chr)
    end
  end

  class << self
    def run(&block)
      i = OscillationGenerator.new(&block)
    end
  end

  def output pipe
    @pipe = pipe
  end
  def rate arg
    @rate = arg # Get through @rate, setter provided for prettyness only.
  end

  def whine about
    $stderr.puts(about)
    exit(1)
  end
end

OscillationGenerator.run do
  define :sine do |t|
    math(:sin, t)
  end

  define :cosine do |t|
    math(:cos, t)
  end

  define :square do |t|
    t > 180 ? 1 : -1
  end

  define :sawtooth do |t|
    t / 360
  end

  define :noise do
    rand * 2 - 1
  end

  output $>
  rate 44000

  wave :type => :sine,      :frequency => note(:do)
  wave :type => :cosine,    :frequency => note(:mi, :bemmole, 1.octave), :offset => 90
end

__END__
./oscgen.rb | aplay --rate=44000
