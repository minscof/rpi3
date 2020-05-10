# -*- coding: latin-1 -*-
# XBMC-Jeedom-EVENT - Service

# IMPORT LIBRARIES
import sys
import os
import subprocess
import xbmc
import xbmcgui
import xbmcaddon
import socket
import urllib2
import simplejson
import requests

def linknx_send(ip,jeedombox,api_key,type,value):
##envoi à Jeedom
    try:
        if jeedombox in ["0","2"]:
            url = "http://" + ip + "/core/api/jeeApi.php" 
        else:
            url = "http://" + ip + "/jeedom/core/api/jeeApi.php"
        
        switch_log('Kodi-Jeedom-EVENT: linKNX connecting to ' + url +' with key ' + api_key[:4]+ '...'+api_key[-4:]+ ' and type ' + type )
        results = requests.get(url,
        params={'value': value.encode("utf-8"), 'api': api_key, 'type' : type})
    except Exception, err:
        print err
        xbmc.log('Kodi-Jeedom-EVENT: linKNX connection failed')

def switch_log(message):
#écriture dans la log
    xbmc.log(message)
        
# Information de l'addon
__addon__    = xbmcaddon.Addon()
__addonname__ = __addon__.getAddonInfo('name')
__cwd__      = __addon__.getAddonInfo('path')
__author__    = __addon__.getAddonInfo('author')
__version__   = __addon__.getAddonInfo('version')
__dbg__ = __addon__.getSetting('debug_mod')    
        
xbmc.log('Kodi-Jeedom-EVENT: Addon information')
xbmc.log('Kodi-Jeedom-EVENT: ----> Addon name    : ' + __addonname__)
xbmc.log('Kodi-Jeedom-EVENT: ----> Addon path    : ' + __cwd__)
xbmc.log('Kodi-Jeedom-EVENT: ----> Addon author  : ' + __author__ )
xbmc.log('Kodi-Jeedom-EVENT: ----> Addon version : ' + __version__)

# Paramètre de l'adoon
my_ip = __addon__.getSetting("ip")
my_jeedombox = __addon__.getSetting("jeedombox")
my_api_key = __addon__.getSetting("api_key")
switch_log('Kodi-Jeedom-EVENT: Addon Host settings')
switch_log('Kodi-Jeedom-EVENT: IP number          : ' + my_ip)
switch_log('Kodi-Jeedom-EVENT: JeedomBox          : ' + my_jeedombox)
switch_log('Kodi-Jeedom-EVENT: APIKey            : ' + my_api_key)

# Démarrage du service 
xbmc.log('Kodi-Jeedom-EVENT: STARTUP')

switch_log('Kodi-Jeedom-EVENT: START EVENT')

# Information du player
switch_log('Kodi-Jeedom-EVENT: NEW CLASS PLAYER')
VIDEO=0
AUDIO=0

def Jeedom(value):

    my_ip = __addon__.getSetting("ip")
    my_jeedombox = __addon__.getSetting("jeedombox")
    my_api_key = __addon__.getSetting("api_key")
    my_type = "kodi"
    my_value = value
    linknx_send(my_ip,my_jeedombox,my_api_key,my_type,my_value)
    
    switch_log('########### ENVOI VERS JEEDOM ###########')
    switch_log(value.encode('utf-8'))
    switch_log('######### FIN ENVOI VERS JEEDOM #########')


class MyPlayer(xbmc.Player):
    def __init__ (self):
        xbmc.Player.__init__(self)
        switch_log('Kodi-Jeedom-EVENT: Class player is initialized')
        Jeedom(u'{"title":"Aucun","status":"Démarré","status_id":"0","cover":"aucun","type":"aucun","genre":"aucun","endtime":"aucun","statusmedia":"aucun"}')

    def onPlayBackStarted(self):
        global AUDIO
        global VIDEO
        xbmc.sleep(200) # pause pour être sur de récupérer l'information
        genre=u'aucun'
        reqjsonplayer=xbmc.executeJSONRPC('{"jsonrpc": "2.0", "method": "Player.GetActivePlayers", "id": 1}')
        player=unicode(reqjsonplayer, 'utf-8', errors='ignore')
        player=simplejson.loads(player)
        playerid=player["result"][0]["playerid"]
        reqjsonmedia = xbmc.executeJSONRPC('{"jsonrpc": "2.0", "method": "Player.GetItem", "params": { "properties": ["fanart","thumbnail","tvshowid","firstaired"], "playerid": %d}, "id": 1}'% (playerid))
        media = unicode(reqjsonmedia, 'utf-8', errors='ignore')                                                
        media = simplejson.loads(media)
        thumbnail=media["result"]["item"]["thumbnail"].replace('image://','')
        if thumbnail=='':
        	thumbnail='%2fstorage%2f.kodi%2fuserdata%2faddon_data%2fscreensaver.video%2fvideos%2faquarium-screensaver.jpg'
        	switch_log(thumbnail)
		if "tvshowid" in media["result"]["item"] and media["result"]["item"]["tvshowid"]!= -1:
            reqjsonshow = xbmc.executeJSONRPC('{"jsonrpc": "2.0", "method": "VideoLibrary.GetTVShowDetails", "params": { "properties": ["thumbnail","genre"], "tvshowid": %d}, "id": 1}'% (media["result"]["item"]["tvshowid"]))
            show = unicode(reqjsonshow, 'utf-8', errors='ignore')                                
            show = simplejson.loads(show)
            thumbnail=show["result"]["tvshowdetails"]["thumbnail"].replace('image://','')
            year=media["result"]["item"]["firstaired"]
            genre=u''
            for x in show["result"]["tvshowdetails"]["genre"]:
                if x==show["result"]["tvshowdetails"]["genre"][0]:
                    genre=genre+x
                else:
                    genre=genre+' / '+x
        if xbmc.Player().isPlayingVideo():
            endtime=xbmc.getInfoLabel("Player.FinishTime('hh:mm')").replace(':','')
            plot=xbmc.getInfoLabel("VideoPlayer.Plot").decode("utf-8").replace('"','\'')
            if xbmc.getInfoLabel("VideoPlayer.TVShowTitle"):
                epi=xbmc.getInfoLabel("VideoPlayer.Episode")
                sais=xbmc.getInfoLabel("VideoPlayer.Season")
                if len(epi)<2:
                    epi='0'+epi
                if len(sais)<2:
                    sais='0'+sais
                title= xbmc.getInfoLabel("VideoPlayer.TVShowTitle") +' : S'+  sais +'E'+ epi+' - '+xbmc.getInfoLabel("VideoPlayer.Title").replace('"','\'')
                type=u'Séries'
            else:
                year=xbmc.getInfoLabel("VideoPlayer.Year")
                genre=xbmc.getInfoLabel("VideoPlayer.Genre").decode("utf-8")
                title = xbmc.getInfoLabel("VideoPlayer.Title").replace('"','\'')
                type=u'Films'
	    	if "screensaver" in title:
				title="aquarium"
            VIDEO = 1
            AUDIO = 0
            Jeedom(u'{"title":"'+title.decode("utf-8")+u'","status":"Vidéo en cours","status_id":"1","cover":"'+thumbnail.decode("utf-8")+u'","type":"'+type+u'","genre":"'+genre+u'","endtime":"'+endtime.decode("utf-8")+'","statusmedia":"Lecture","year":"'+year+'","plot":"'+plot+'"}')
        if xbmc.Player().isPlayingAudio() == True:
            endtime=xbmc.getInfoLabel("Player.FinishTime('hh:mm')").replace(':','')
            type=u'Audio'
            genre=xbmc.getInfoLabel("MusicPlayer.Genre").decode("utf-8")
            title = xbmc.getInfoLabel("MusicPlayer.Artist") + " - " + xbmc.getInfoLabel("MusicPlayer.Title")
            year = xbmc.getInfoLabel("MusicPlayer.Year").replace('"','\'')
            nextsong = '<li>En cours : ' +xbmc.getInfoLabel("MusicPlayer.Artist") +' - ' +xbmc.getInfoLabel("MusicPlayer.Title") + '</li><li>2 : ' +xbmc.getInfoLabel("MusicPlayer.offset(1).Artist") +' - ' +xbmc.getInfoLabel("MusicPlayer.offset(1).Title") + '</li><li>3 : ' +xbmc.getInfoLabel("MusicPlayer.offset(2).Artist") +' - ' +xbmc.getInfoLabel("MusicPlayer.offset(2).Title") + '</li><li>4 : ' +xbmc.getInfoLabel("MusicPlayer.offset(3).Artist") +' - ' +xbmc.getInfoLabel("MusicPlayer.offset(3).Title") + '</li><li>5 : ' +xbmc.getInfoLabel("MusicPlayer.offset(4).Artist") +' - ' +xbmc.getInfoLabel("MusicPlayer.offset(4).Title") + '</li><li>6 : ' +xbmc.getInfoLabel("MusicPlayer.offset(5).Artist") +' - ' +xbmc.getInfoLabel("MusicPlayer.offset(5).Title") + '</li><li>7 : ' +xbmc.getInfoLabel("MusicPlayer.offset(6).Artist") +' - ' +xbmc.getInfoLabel("MusicPlayer.offset(6).Title") + '</li><li>8 : ' +xbmc.getInfoLabel("MusicPlayer.offset(7).Artist") +' - ' +xbmc.getInfoLabel("MusicPlayer.offset(7).Title") + '</li><li>9 : ' +xbmc.getInfoLabel("MusicPlayer.offset(8).Artist") +' - ' +xbmc.getInfoLabel("MusicPlayer.offset(8).Title") + '</li><li>10 : ' +xbmc.getInfoLabel("MusicPlayer.offset(9).Artist") +' - ' +xbmc.getInfoLabel("MusicPlayer.offset(9).Title")+'</li>'
            nextsong=nextsong.replace('<li>2 :  - </li>','').replace('<li>3 :  - </li>','').replace('<li>4 :  - </li>','').replace('<li>5 :  - </li>','').replace('<li>6 :  - </li>','').replace('<li>7 :  - </li>','').replace('<li>8 :  - </li>','').replace('<li>9 :  - </li>','').decode("utf-8").replace('"','\'')
            playlistposition = xbmc.getInfoLabel("MusicPlayer.PlaylistPosition")
            playlistlength= xbmc.getInfoLabel("MusicPlayer.PlaylistLength")
            VIDEO = 0
            AUDIO = 1
            Jeedom(u'{"title":"'+title.decode("utf-8")+u'","status":"Audio en cours","status_id":"2","cover":"'+thumbnail.decode("utf-8")+u'","type":"'+type+u'","genre":"'+genre+u'","endtime":"'+endtime.decode("utf-8")+'","statusmedia":"Lecture","position":"'+playlistposition+'","longueur":"'+playlistlength+'","nextsong":"'+nextsong+'","year":"'+year+'"}')
        if (xbmc.getInfoLabel("VideoPlayer.ChannelNumber") !=  ''):
            pvr_name = xbmc.getInfoLabel("VideoPlayer.ChannelName")
            title = xbmc.getInfoLabel("ListItem.Title")
            pvr_number = xbmc.getInfoLabel("VideoPlayer.ChannelNumber")
            endtime = xbmc.getInfoLabel("ListItem.EndTime('hh:mm')").replace(':','')
            status = pvr_number.decode("utf-8")+' - '+pvr_name.decode("utf-8")
            type=u'Séries'
            VIDEO = 1
            AUDIO = 0
            Jeedom(u'{"title":"'+pvr_title.decode("utf-8")+u'","status":"'+status+u'","status_id":"1","cover":"aucun","type":"'+type+u'","genre":"aucun","endtime":"'+endtime.decode("utf-8")+'","statusmedia":"Lecture"}')
            
    def onPlayBackEnded(self):
    	global AUDIO
        global VIDEO        
        if (VIDEO == 1):
            Jeedom(u'{"title":"Aucun","status":"Vidéo terminée","status_id":"3","cover":"aucun","type":"aucun","genre":"aucun","endtime":"aucun","statusmedia":"Stop"}')
        if (AUDIO == 1):
            Jeedom(u'{"title":"Aucun","status":"Audio terminée","status_id":"4","cover":"aucun","type":"aucun","genre":"aucun","endtime":"aucun","statusmedia":"Stop"}')

    def onPlayBackStopped(self):
    	global AUDIO
        global VIDEO
        if (VIDEO == 1):
            Jeedom(u'{"title":"Aucun","status":"Vidéo arrêtée","status_id":"5","cover":"aucun","type":"aucun","genre":"aucun","endtime":"aucun","statusmedia":"Stop"}')

        if (AUDIO == 1):
            Jeedom(u'{"title":"Aucun","status":"Audio arrêtée","status_id":"6","cover":"aucun","type":"aucun","genre":"aucun","endtime":"aucun","statusmedia":"Stop"}')

    def onPlayBackPaused(self):
        if xbmc.Player().isPlayingVideo():
            Jeedom(u'{"title":"old","status":"Vidéo en pause","status_id":"7","cover":"old","type":"Pause","genre":"old","endtime":"old","statusmedia":"Pause"}')

        if xbmc.Player().isPlayingAudio():
            Jeedom(u'{"title":"old","status":"Audio en pause","status_id":"8","cover":"old","type":"Audio","genre":"old","endtime":"old","statusmedia":"Pause"}')

    def onPlayBackResumed(self):
        if xbmc.Player().isPlayingVideo():
            endtime=xbmc.getInfoLabel("Player.FinishTime('hh:mm')").replace(':','')
            if xbmc.getInfoLabel("VideoPlayer.TVShowTitle"):
                Jeedom(u'{"title":"old","status":"Reprise vidéo","status_id":"9","cover":"old","type":"Séries","genre":"old","endtime":"'+endtime.decode("utf-8")+'","statusmedia":"Lecture"}')
            else:
                Jeedom(u'{"title":"old","status":"Reprise vidéo","status_id":"9","cover":"old","type":"Films","genre":"old","endtime":"'+endtime.decode("utf-8")+'","statusmedia":"Lecture"}')

        if xbmc.Player().isPlayingAudio():
            endtime=xbmc.getInfoLabel("Player.FinishTime('hh:mm')").replace(':','')
            Jeedom(u'{"title":"old","status":"Reprise audio","status_id":"10","cover":"old","type":"Audio","genre":"old","endtime":"'+endtime.decode("utf-8")+'","statusmedia":"Lecture"}')

class VolumeLink():
    def __init__(self):
       self.jeedomVolume = 0
       self.jeedomMuted = False

    def updatejeedomVolume(self):

       # Get the current XBMC Volume
       xbmcVolume, xbmcMuted = self._getXbmcVolume()
       # Check to see if it has changed, and if we need to change the jeedom value
       if (xbmcVolume != -1) and (xbmcVolume != self.jeedomVolume) and not xbmcMuted :
          Jeedom(u'{"volume":"'+ str(xbmcVolume)+'"}')
          self.jeedomVolume = xbmcVolume

       # Check to see if XBMC has been muted
       if (xbmcMuted != -1) and (xbmcMuted != self.jeedomMuted):
          if xbmcMuted:
            Jeedom(u'{"volume": "0"}')
          else :
            Jeedom(u'{"volume":"'+ str(xbmcVolume)+'"}')
          self.jeedomMuted = xbmcMuted

    # This will return the volume in a range of 0-100
    def _getXbmcVolume(self):
       result = xbmc.executeJSONRPC('{"jsonrpc": "2.0", "method": "Application.GetProperties", "params": { "properties": [ "volume", "muted" ] }, "id": 1}')
       json_query = simplejson.loads(result)

       volume = -1
       if ("result" in json_query) and ('volume' in json_query['result']):
          # Get the volume value
          volume = json_query['result']['volume']

       muted = None
       if ("result" in json_query) and ('muted' in json_query['result']):
          # Get the volume value
          muted = json_query['result']['muted']

       return volume, muted

##Début du script
argc = len(sys.argv)
switch_log( "Jeedom -> Script argument is " + str(sys.argv))

try:
    params=get_params(sys.argv[2])
except:
    params={}
    
if argc == 1:
    volumeLink = VolumeLink()
    player=MyPlayer()
    while(not xbmc.abortRequested):
        volumeLink.updatejeedomVolume()
        xbmc.sleep(1000)

    if str(__addon__.getSetting("xbmc_ended")) == "Oui":
        Jeedom(u'{"title":"Aucun","status":"Arrêt","status_id":"18","cover":"aucun","type":"aucun","genre":"aucun","endtime":"aucun","statusmedia":"aucun"}')
else:
    switch_log( "Jeedom -> Script a traiter")
    
