##################################################################################
# Copyright ©2011 lee8oi@gmail.com
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# http://www.gnu.org/licenses/
############################################
#uncomment to enable local copy of http.tcl
#source "http.tcl"
#package require http 2.5.3
############################################
#
package require http
package require tls
package require htmlparse
::http::register https 443 [list ::tls::socket -require 0 -request 1]
set urls {
	"http://www.google.com"
	"http://forum.egghelp.org/viewtopic.php?t=16819"
	"http://fishki.net/comment.php?id=20554"
	"http://www.nicovideo.jp/video_top"
	"http://www.duzheer.com/youqingwenzhang/"
	"http://plus.google.com"
}
puts "package version: [package provide http]"
puts "running grabby"
puts "encoding system: [encoding system]"
proc grabby {url} {
	set sysencoding [encoding system]
	catch {set http [::http::geturl $url -timeout 60000]} error
	if {[info exists http]} {
		if { [::http::status $http] == "timeout" } {
			puts "Oops timed out."
			return 0
		}
		upvar #0 $http state
		array set meta $state(meta)
		puts "State url: $state(url)"
		foreach {name value} $state(meta) {
			if {[regexp -nocase ^location$ $name]} {
				# Handle URL redirects
				puts "redirect found: $value"
				grabby $value
				return 0
			}
		}
		puts "State type: $state(type)"
		puts "Document encoding: $state(charset)"
		set cleancharset [string map -nocase {"ISO-" "iso" "UTF-" "utf-" "windows-" "cp" "shift_jis" "shiftjis"} $state(charset)]
		#set cleancharset [string map -nocase {"iso8859-1" "latin1"} $cleancharset]
		puts "Cleaned charset name: $cleancharset"
		set data [::http::data $http]
		if {[regexp -nocase {"Content-Type" content=".*?; charset=(.*?)".*?>} $data - char]} {
			#get charset from content type
			puts "Charset from Content-Type: $char"
			set char [string trim [string trim $char "\"' /"] {;}]
			regexp {^(.*?)"} $char - char
			set mset $char
			if {![string length $char]} { set char "None Given" ; set char2 "None Given" }
			set char2 [string tolower [string map -nocase {"ISO-" "iso" "UTF-" "utf-" "iso-" "iso" "windows-" "cp" "shift_jis" "shiftjis"} $char]]
			puts "Charset after mapping: $char2"
		} else {
			if {[regexp -nocase {<meta content=".*?; charset=(.*?)".*?>} $data - char]} {
				puts "charset from meta content: $char"
				#get charset from meta content
				set char [string trim $char "\"' /"]
				regexp {^(.*?)"} $char - char
				set mset $char
				if {![string length $char]} { set char "None Given" ; set char2 "None Given" }
				set char2 [string tolower [string map -nocase {"ISO-" "iso" "UTF-" "utf-" "iso-" "iso" "windows-" "cp" "shift_jis" "shiftjis"} $char]]
				puts "charset after mapping: $char2"
			} else {
				puts "charset not found in content-type or meta-content"
				set char "None Given" ; set char2 "None Given" ; set mset "None Given"
			}
		}
		set char3 [string tolower [string map -nocase {"ISO-" "iso" "UTF-" "utf-" "iso-" "iso" "windows-" "cp" "shift_jis" "shiftjis"} $state(charset)]]
		if {![string equal -nocase $char2 $char3]} {
			switch $char3 {
				"iso8859-1" {
					puts "ISO8859-1 DETECTED"
					set data [encoding convertfrom $char2 $data]
				}
				default {
					set data [encoding convertfrom $char3 $data]
				}
			}
		} else {
			puts "Encodings match or are none given."
			#set data [encoding convertto [encoding system] $data]
		}
		::http::cleanup $http
		set title ""
		if {[regexp -nocase {<title>(.*?)</title>} $data match title]} {
			set output [string map { {href=} "" \" "" } $title]
			regsub -all -- {(?:<b>|</b>)} $output "\002" output
				regsub -all -- {<.*?>} $output "" output
				regsub -all -- {(?:<b>|</b>)} $output "\002" output
				regsub -all -- {<.*?>} $output "" output
				regsub -all \{ $output {\&ob;} output
				regsub -all \} $output {\&cb;} output
				puts "Title: [htmlparse::mapEscapes $output]"
		}
		return 1
	} else {
		puts "no http data found."
		return 0
	}
	
}
foreach url $urls {
	puts "infor for $url: [grabby $url]"
}

