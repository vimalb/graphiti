# Veritabill 1.0.0, June 11, 2012
# Copyright (c) 2012 Prior Knowledge, Inc.
# Questions? Contact Max Gasner <max@priorknowledge.com>.
#
# Quick script to convert the .csv output by our generative process (/scripts/synthetic.R) into a ruby hash (output to /scripts/seed.rb) that we can easily use to seed our application database
require 'veritable'

DATASOURCE = "seed_data.csv"

seed = File.open("seed.rb", mode = "w") {|f|
  f.puts("SEED_DATA = #{Veritable::Util.read_csv(DATASOURCE)}")
}
