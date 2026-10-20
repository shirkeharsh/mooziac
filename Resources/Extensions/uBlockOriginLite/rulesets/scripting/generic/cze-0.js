/*******************************************************************************

    uBlock Origin Lite - a comprehensive, MV3-compliant content blocker
    Copyright (C) 2014-present Raymond Hill

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see {http://www.gnu.org/licenses/}.

    Home: https://github.com/gorhill/uBlock
*/

// cze-0

// Important!
// Isolate from global scope
(function uBOL_cssGenericImport() {

const lowlyGeneric = new Map(/* 42 */[[1275,"#ad_popup"],[59419,"#adRectangle"],[60256,"#onlajny-stickers"],[10624,"#promo-box"],[19810,"#reklama-etarget"],[2331,"#reklamni-box"],[15841,"#reklamy"],[48368,"#sklik"],[31243,"#slevomat_ad"],[24947,"#topbanner"],[29355,"#zivefirmy"],[45393,".adform-adbox"],[14401,".bx-leaderboard"],[5532,".cnc-ads"],[3869,".etarget"],[25079,".hp-advert"],[61701,".jobscz"],[56213,".lsads-banner"],[63618,".nativead"],[8568,".ownad"],[10528,".perex-adblock-warning"],[45244,".r-main"],[55277,".reklama-3"],[33024,".reklama-bottom"],[10310,".reklama-box"],[22993,".reklama-left"],[19524,".reklama-lista"],[39957,".reklama-megaboard"],[9307,".reklama-right"],[9496,".reklama-top"],[20396,".reklamaBottom"],[59882,".reklamaHorniLista"],[31962,".reklama_ahead"],[17901,".reklama_square"],[38066,".rklm"],[11261,".sklik"],[53719,".sklik-block"],[10601,".sklik-box"],[51482,".sklik_left"],[36048,".sklik_right"],[43396,".topreklama"],[59437,".vreklama"]]);
const highlyGeneric = /* 4 */"[id^=\"etarget\"],\n[id^=\"aswift\"],\n[id^=\"sklikReklama\"],\n[id^=\"sm-ad\"]";
const exceptions = /* 12 */[".ads-box\n.reklama-box",".g_ad","#adsense",".r-main",".adBanner",".reklama","#adverts",".advertising-content",".reklama",".reklama",".rklm","#ad_skin"];
const hostnames = /* 12 */["denik.cz","novinky.cz","skrblik.cz","hyundai.com","aktuality.sk","mazdaclub.cz","sluzebnik.cz","vranovske.sk","nissanclub.cz","jaguar-club.net","www.parabola.cz","dobre-recepty.sk"];
const hasEntities = false;

self.genericSelectorMaps = self.genericSelectorMaps ?? [];
self.genericSelectorMaps.push(lowlyGeneric);
self.genericDetails = self.genericDetails ?? [];
self.genericDetails.push({ highlyGeneric, exceptions, hostnames, hasEntities });

})();

/******************************************************************************/
