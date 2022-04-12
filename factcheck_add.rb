#!/usr/bin/env ruby
# coding: utf-8

# Ce script ajoute les attributs de vérification
# sur les sources des évènements

require 'nokogiri'

document = Nokogiri::XML(open('reference.xml').read)
