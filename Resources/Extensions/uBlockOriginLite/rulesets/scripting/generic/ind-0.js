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

// ind-0

// Important!
// Isolate from global scope
(function uBOL_cssGenericImport() {

const lowlyGeneric = new Map(/* 0 */undefined);
const highlyGeneric = /* 0 */"";
const exceptions = /* 7 */[".np-ads-wrapper\n.np-header-ads-area",".header-ads",".td-ad-m\n.td-ad-p\n.td-ad-tp",".np-ads-wrapper",".header-ads",".np-ads-wrapper\n.np-header-ads-area",".td-ad-m\n.td-ad-p\n.td-ad-tp"];
const hostnames = /* 7 */["abnewslive.in","divyalive.com","dainikdawa.com","nepalimato.com","chirantannews.in","onlinejalandhar.com","dainikbharatbhaskar.com"];
const hasEntities = false;

self.genericSelectorMaps = self.genericSelectorMaps ?? [];
self.genericSelectorMaps.push(lowlyGeneric);
self.genericDetails = self.genericDetails ?? [];
self.genericDetails.push({ highlyGeneric, exceptions, hostnames, hasEntities });

})();

/******************************************************************************/
