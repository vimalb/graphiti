# Veritabill 1.0.0, June 11, 2012
# Copyright (c) 2012 Prior Knowledge, Inc.
# Questions? Contact Max Gasner <max@priorknowledge.com>.

# This script seeds the postgres store with seed data, runs an initial Veritable analysis,  retrieves Veritable estimates of the time tasks will take, and stores them

require 'veritable'
require 'data_mapper'
require_relative 'seed' # store seed data as a ruby hash

DataMapper.setup(:default, ENV['DATABASE_URL'] || 'postgres://localhost/mydb')

class Task
  include DataMapper::Resource
  property :id, Serial
  property :user_class, String
  property :user, String
  property :day, String
  property :time_of_day, String
  property :client, String
  property :true_time, Integer
  property :user_estimate, Integer # user's estimate
  property :veritable_estimate, Float
end

DataMapper.auto_migrate!

# We include the user's estimate as a conditioning datum, so Veritable can learn (and correct for) individual user biases
schema = Veritable::Schema.new({
  'user' => {'type' => 'categorical'},
  'user_class' => {'type' => 'categorical'},
  'day' => {'type' => 'categorical'},
  'time_of_day' => {'type' => 'categorical'},
  'client' => {'type' => 'categorical'},
  'true_time' => {'type' => 'count'},
  'user_estimate' => {'type' => 'count'} 
})
records = SEED_DATA
Veritable::Util.clean_data(records, schema) # normalize the data

api = Veritable.connect
api.tables.each {|t| t.delete} # remove existing tables, if any
t = api.create_table('veritabill')

records.each {|r|
  Task.create({ # add to postgres
    :user => r['user'],
    :user_class => r['user_class'],
    :day => r['day'],
    :time_of_day => r['time_of_day'],
    :client => r['client'],
    :true_time => r['true_time'],
    :user_estimate => r['user_estimate']
  })
  t.upload_row(r) # upload to veritable
}

a = t.create_analysis(schema, 'veritabill_0')
a.wait

Task.all.each {|r|
  h = r.attributes
  h.update({:true_time => nil})
  h.delete(:veritable_estimate)
  h.delete(:id)
  kk, vv = h.collect {|k, v| k.to_s}, h.collect {|k, v| v}
  h = {}
  (0...(kk.size)).each {|i| h[kk[i]] = vv[i]}
  veritable_estimate = a.predict(h)
  r.update({
    :veritable_estimate => veritable_estimate['true_time']  
    })
}
