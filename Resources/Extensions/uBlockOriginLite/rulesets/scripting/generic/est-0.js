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

// est-0

// Important!
// Isolate from global scope
(function uBOL_cssGenericImport() {

const lowlyGeneric = new Map(/* 2 */[[9831,".article-share"],[63225,".article-share__item"]]);
const highlyGeneric = /* 7 */"A[href*=\"http://pay4results24.eu\"],\niframe[src*=\"cherrystatic.net\"],\niframe[src*=\"date.elu24.ee\"],\nIFRAME[src*=\"sale24.ee\"],\niframe[src*=\"static.chilli.ee\"],\niframe[src*=\"superdeal.ee\"],\niframe[src*=\"hotelliveeb.ee\"]";
const exceptions = /* 2 */[".article-share\n.article-share__item","iframe[src*=\"hotelliveeb.ee\"]"];
const hostnames = /* 2 */["postimees.ee","hotelliveeb.ee"];
const hasEntities = false;

self.genericSelectorMaps = self.genericSelectorMaps ?? [];
self.genericSelectorMaps.push(lowlyGeneric);
self.genericDetails = self.genericDetails ?? [];
self.genericDetails.push({ highlyGeneric, exceptions, hostnames, hasEntities });

})();

/******************************************************************************/
