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

// grc-0

// Important!
// Isolate from global scope
(function uBOL_cssGenericImport() {

const lowlyGeneric = new Map(/* 3 */[[21195,".adsbox"],[16879,"DIV.agores300"],[39349,"TABLE.advright"]]);
const highlyGeneric = /* 5 */"A[href*=\"adman.otenet.gr/click?\"],\nA[href*=\"http://affiliates.stanjamesaffiliates.com/\"],\nA[href*=\"http://axiabanners.exodus.gr/\"],\nA[href*=\"http://interactive.forthnet.gr/click?\"],\nA[href*=\"serve.williamhill.com/\"]";
const exceptions = /* 3 */[".pub_300x250\n.pub_728x90\n.text-ad\n.textAd\n.text_ad",".adResult",".ad_wrapper"];
const hostnames = /* 3 */["ediva.gr","aggeliestanea.gr","athensmagazine.gr"];
const hasEntities = false;

self.genericSelectorMaps = self.genericSelectorMaps ?? [];
self.genericSelectorMaps.push(lowlyGeneric);
self.genericDetails = self.genericDetails ?? [];
self.genericDetails.push({ highlyGeneric, exceptions, hostnames, hasEntities });

})();

/******************************************************************************/
