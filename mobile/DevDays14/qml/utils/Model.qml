import QtQuick 2.0
import st.app.models 1.0 as Models
import "SettingStatements.js" as SettingStatements

Models.SQLiteDatabase {
    id: root
    source: "devdays14.sqlite3"

    signal favoritesModelReady(variant model)
    signal addedFavoritesTrack(string trackId)
    signal removedFavoritesTrack(string trackId)
    signal dateReady
    property variant favoritesModel : []
    property variant favoritesHash : []
    property variant today : new Date()

    // Persistent storage

    property string tableFavorites : "favorites"

    function initialize()
    {
        createSettingTable()
        createFavoritesTable()
        getFavorites()
        today = new Date(2014, 10, 03, 1, 13, 09)
        _Timer_Date.restart()
    }



    function createFavoritesTable()
    {
        var q = "CREATE TABLE IF NOT EXISTS %0(track_id TEXT, track_object TEXT, sessionDate DATETIME, insertionDate DATETIME)"
        .replace(/%0/g, tableFavorites);

        executeQuery(q, function(query, status, result) {
        })
    }

    function insertFavorite(trackObject)
    {
        var q = "INSERT INTO %0 VALUES ('%1', '%2', %3, %4)"
        .replace(/%0/g, tableFavorites)
        .replace(/%1/g, trackObject.id)
        .replace(/%2/g, Qt.btoa(JSON.stringify(trackObject)))
        .replace(/%3/g, "datetime('"+Qt.formatDateTime(new Date(trackObject.date.plain.starting), "yyyy-MM-dd HH:mm:ss")+"')")
        .replace(/%4/g, "datetime('"+Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")+"')")

        executeQuery(q, function(query, status, result)
        {
            if(status)
            {
                addedFavoritesTrack(trackObject.id)
                getFavorites()
            }
        });
    }

    function removeFavorite(trackObject)
    {
        var q = "DELETE FROM %0 WHERE track_id = '%1'"
        .replace(/%0/g, tableFavorites)
        .replace(/%1/g, trackObject.id);

        executeQuery(q, function(query, status, result)
        {
            if(status)
            {
                removedFavoritesTrack(trackObject.id)
                getFavorites()
            }
        });
    }

    function favoritesModelContainsTrack(trackId)
    {
        return favoritesHash.indexOf(trackId)>-1
    }


    function getFavorites()
    {
        var q = "SELECT * FROM %0 ORDER BY sessionDate ASC".replace(/%0/g, tableFavorites)
        executeQuery(q, function(query, status, result)
        {
            if(status)
            {
                result = result.map(function(e) {
                    var o = JSON.parse(JSON.stringify(e))
                    o.trackObject = JSON.parse(Qt.atob(e.track_object))
                    delete o.track_object
                    return o
                })
                favoritesHash = result.map(function(e) {
                    return e.track_id
                })
                root.favoritesModel = result
                root.favoritesModelReady(result)
            }
        });
    }


    // Settings Data

    signal retrievedValueForKey(string key, string value)

    property string keyEducated : "educated"

    function createSettingTable()
    {
        executeQuery(SettingStatements.createSettingsTable, function(queryString, status, result) {
            if(status)
            {
            }
        });
    }

    function getSettingForKey(settingKey, callback)
    {
        if(typeof settingKey === "undefined") return callback(false, false) || false;
        executeQuery(SettingStatements.getSettingStatement(settingKey), function(queryString, status, result) {
            if(status && result.length > 0)
            {
                retrievedValueForKey(result[0].key, result[0].value)
                if(callback)
                    callback(result[0].key, result[0].value)
            } else
            {
                if(callback)
                    callback(false, false)
            }
        });
    }

    function insertSetting(settingKey, settingValue, callback)
    {
        executeQuery(SettingStatements.insertSettingStatement(settingKey, settingValue), function(queryString, status, result) {
            if(callback)
                callback(status)
        });
    }

    function removeSetting(settingKey, callback)
    {
        executeQuery(SettingStatements.removeSettingStatement(settingKey), function(query, result, status) {
            if(callback)
                callback(status)
        });
    }


    // API data
    property int apiStatus : Loader.Null

    property variant schedule
    property variant track
    property variant legend
    property variant information

    function reload()
    {
        apiStatus = Loader.Loading
        _Timer_Debouncer.restart()

        webRequest(_config.apiInformation, function(response, request, requestUrl) {
            information = response
            _Timer_Debouncer.stop()
        })

        webRequest(_config.apiLegend, function(response, request, requestUrl) {

            var legend = new Object
            if(!response) return
            response.map(function(e) {
                legend[e.id] = e
            })
            root.legend = legend

            webRequest(_config.apiSchedule, function(response, request, requestUrl) {
                schedule = response
                dateReady(today)
                apiStatus = Loader.Ready
                _Timer_Debouncer.stop()
            })
            webRequest(_config.apiTracks, function(response, request, requestUrl) {
                track = response
                _Timer_Debouncer.stop()
            })
        })
    }

    // Temporary model retriever

    function webRequest(requestUrl, callback){
        console.log("url="+requestUrl)
        var request = new XMLHttpRequest();
        request.onreadystatechange = function() {
            var response;
            if(request.readyState === XMLHttpRequest.DONE) {
                if(request.status === 200) {
                    response = JSON.parse(request.responseText);
                } else {
                    console.log("Server: " + request.status + "- " + request.statusText);
                    apiStatus = Loader.Error
                    response = ""
                }
                callback(response, request, requestUrl)
            }
        }
        request.open("GET", requestUrl, true); // only async supported
        request.send();
    }

    // Date helpers
    function date_isRightNow(start, end)
    {
//        console.log("date_isRightNow?")
        var s = new Date(start)
        var e = new Date(end)
//        console.log("start =",s)
//        console.log("end =",e)
//        console.log("today="+today)
//        console.log("??="+(today > s && today < e))
        return today > s && today < e
    }

    Component.onCompleted: {
        initialize()

        webRequest(_config.apiRoute, function(response, request, requestUrl) {
            if(response)
            {
                console.log("api version is " + response.version)
                _config.apiBaseUrl = response.url
            }
            reload()
        })
    }

}
