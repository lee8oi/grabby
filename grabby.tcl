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
#NOTE: This script is being developed for http 2.7.x mainly.
#source "http.tcl"
#package require http 2.5.3
############################################
#
package require http
package require tls
package require htmlparse
::http::register https 443 ::tls::socket
set urls {
	"http://google.com"
	"http://forum.egghelp.org/viewtopic.php?t=16819"
	"http://fishki.net/comment.php?id=20554"
	"http://www.nicovideo.jp/video_top"
	"http://www.duzheer.com/youqingwenzhang/"
	"https://plus.google.com"
}
puts "package version: [package provide http]"
puts "encoding system: [encoding system]"

proc grabtitle {data} {
	if {[regexp -nocase {<title>(.*?)</title>} $data match title]} {
		set output [string map { {href=} "" \" "" } $title]
		regsub -all -- {(?:<b>|</b>)} $output "\002" output
			regsub -all -- {<.*?>} $output "" output
			regsub -all -- {(?:<b>|</b>)} $output "\002" output
			regsub -all -- {<.*?>} $output "" output
			regsub -all \{ $output {\&ob;} output
			regsub -all \} $output {\&cb;} output
			#puts "Title: [htmlparse::mapEscapes $output]"
			return "[htmlparse::mapEscapes $output]"
	}
}

proc grabby {url} {
	set ua "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.0.5) Gecko/2008120122 Firefox/3.0.5"
	set http [::http::config -useragent $ua]
	catch {set http [::http::geturl $url -timeout 60000]} error
	if {[info exists http]} {
		if { [::http::status $http] == "timeout" } {
			puts "Oops timed out."
			return 0
		}
		upvar #0 $http state
		array set meta $state(meta)
		set url $state(url)
		set data [::http::data $http]
		foreach {name value} $state(meta) {
			if {[regexp -nocase ^location$ $name]} {
				set mapvar [list " " "%20"]
				::http::cleanup $http
				catch {set http [::http::geturl $value -timeout 60000]} error
				if {![string match -nocase "::http::*" $error]} {
					return "http error: [string totitle $error] \( $value \)"
				}
				if {![string equal -nocase [::http::status $http] "ok"]} {
					return "status: [::http::status $http]"
				}
				set url [string map {" " "%20"} $value]
				upvar #0 $http state
				if {[incr r] > 10} { puts "redirect error (>10 too deep) \( $url \)" ; return 0}
				set data [::http::data $http]
			}
		}
		if {[regexp -nocase {"Content-Type" content=".*?; charset=(.*?)".*?>} $data - char]} {
			#get charset from content type
			set char [string trim [string trim $char "\"' /"] {;}]
			regexp {^(.*?)"} $char - char
			if {![string length $char]} { set char "None Given" ; set char2 "None Given" }
			set char2 [string tolower [string map -nocase {"ISO-" "iso" "UTF-" "utf-" "iso-" "iso" "windows-" "cp" "shift_jis" "shiftjis"} $char]]
		} else {
			if {[regexp -nocase {<meta content=".*?; charset=(.*?)".*?>} $data - char]} {
				#get charset from meta content
				set char [string trim $char "\"' /"]
				regexp {^(.*?)"} $char - char
				if {![string length $char]} { set char "None Given" ; set char2 "None Given" }
				set char2 [string tolower [string map -nocase {"ISO-" "iso" "UTF-" "utf-" "iso-" "iso" "windows-" "cp" "shift_jis" "shiftjis"} $char]]
				puts "Mapped charset: $char2"
			} else {
				set char "None Given" ; set char2 "None Given" ; set mset "None Given"
			}
		}
		set char3 [string tolower [string map -nocase {"ISO-" "iso" "UTF-" "utf-" "iso-" "iso" "windows-" "cp" "shift_jis" "shiftjis"} $state(charset)]]
		if {![string equal -nocase $char2 $char3]} {
			if {[catch {set data [encoding convertfrom $char2 $data]} error]} {
				set data [encoding convertfrom $char3 $data]
			}
		} else {
			if {[string match "2.5*" [package provide http]]} {
				set data [encoding convertfrom $char3 $data]
			}
		}
		::http::cleanup $http
		set title [grabtitle $data]
		return $title
	} else {
		return "no data"
	}
	
}

foreach url $urls {
	
	puts "[grabby $url] @ \( $url \)"
}

