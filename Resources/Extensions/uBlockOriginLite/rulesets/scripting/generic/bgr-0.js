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

// bgr-0

// Important!
// Isolate from global scope
(function uBOL_cssGenericImport() {

const lowlyGeneric = new Map(/* 7 */[[33561,"#ea_intext_div"],[62501,"td#freenet_table_ads"],[7167,".lapni-pop-over"],[16796,"#xenium_hot_offers"],[9208,"#banner_ad"],[34288,"#adbody"],[51615,"#newAd,\n#newAd"]]);
const highlyGeneric = /* 0 */"";
const exceptions = /* 4 */["#newAd","#newAd","#banner_ad","#adbody"];
const hostnames = /* 4 */["olx.bg","prodavalnik.com","bg-ikonomika.com","noshtuvki.burkan.info"];
const hasEntities = false;

self.genericSelectorMaps = self.genericSelectorMaps ?? [];
self.genericSelectorMaps.push(lowlyGeneric);
self.genericDetails = self.genericDetails ?? [];
self.genericDetails.push({ highlyGeneric, exceptions, hostnames, hasEntities });

})();

/******************************************************************************/
