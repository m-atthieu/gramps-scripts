#!/usr/bin/env ruby
# coding: utf-8
# ce script fonctionne sur un export JSON d'un arbre
# gramps
# Il va faire une liste des différences entre les deux
# arbres et les fusionner

require 'json'

class GrampsJson
  def initialize filename
    @data = []
    File.foreach(filename) do |line|
      #puts "line #{line}"
      @data << JSON.parse(line)
    end
    puts @data.length
  end
  def get item_type
    @data.select do |d| d['_class'] == item_type end
  end
end

ref = GrampsJson.new 'reference.json'
cur = GrampsJson.new 'current.json'

# returns 3 lists : modified in both, missing in ref, missing in curr
def diff_dbs reference, current
  [ 'Person', 'Family', 'Source',
    'Citation', 'Event', 'Media',
    'Place', 'Repository', 'Note',
    'Tag' ].each do |item_type|
    ref_items = reference.get(item_type)
    cur_items = current.get(item_type)
    ref_handles = ref_items.map do |d| d['handle'] end
    cur_handles = cur_items.map do |d| d['handle'] end
    h = r = 0
    missing_in_ref = []
    missing_in_cur = []
    both_modified = []
    while r < ref_handles.length and c < ref_handles.length
      if ref_handles[r] == cur_handles[c] then
      ref_item = ref.xpath("../*[@handle='#{ref_handles[r]}']")
      cur_item = cur.xpath("../*[@handle='#{cur_handles[c]}']")
      diff = diff_item ref_item, cur_item
      if diff then
        puts "changes in both"
      end
      r += 1
      c += 1
    elsif ref_handles[r] < cur_handles[c] then
      item = ref.xpath("../*[@handle='#{ref_handle[r]}']")
      missing_in_current << item
      puts "missing in current #{item}"
      r += 1
    elsif ref_handles[r] > cur_handles[c] then
      item = cur.xpath("../*[@handle='#{cur_handles[c]}']")
      missing_in_ref << item
      puts "missing in reference #{item}"
      c += 1
    else
      raise 'unsupported'
      end

        while r < ref_handles.length
    item = ref.xpath("../*[@handle='#{ref_handles[r]}']")
    missing_in_ref << item
    puts "missing in reference #{item}"
    r += 1
  end

  while c < cur_handles.length
    item = cur.xpath("../*[@handle='#{cur_handles[c]}']")
    missing_in_cur << item
    puts "missing in current #{item}"
    c += 1
  end

    end
  end
end

differences = diff_dbs ref, cur
