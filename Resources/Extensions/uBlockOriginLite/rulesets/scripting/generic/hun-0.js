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

// hun-0

// Important!
// Isolate from global scope
(function uBOL_cssGenericImport() {

const lowlyGeneric = new Map(/* 56 */[[31080,".ad__main"],[17229,".adblokk"],[21654,".cikk_reklam"],[6820,".cikk-reklam"],[28308,".cikkreklam"],[13904,".google_hirdetes"],[39683,".google_hirdetesek"],[33250,".google-hirdetes"],[22833,".google-hirdetesek"],[60638,".googlehirdetes"],[55525,".googlehirdetesek"],[51592,".hirdetes_box"],[36812,".hirdetes_container,\n.hirdetes-container"],[58149,".hirdetes_doboz"],[55418,".hirdetes-box"],[49047,".hirdetes-doboz"],[15199,".hirdetes-linkek"],[55791,".hirdetesek_box"],[27219,".hirdetesek_container,\n.hirdetesek-container"],[29502,".hirdetesek_doboz"],[59485,".hirdetesek-box"],[46860,".hirdetesek-doboz"],[9293,".optimonk-container"],[45577,".optimonk-iframe-container"],[44700,".optimonk-middle"],[10487,".reklam-doboz"],[60830,".reklamok"],[40448,"#adblokk"],[44600,"#cemp_doboz"],[9252,"#cenmg"],[20667,"#cikk_reklam"],[58953,"#cikk-reklam"],[345,"#cikkreklam"],[59472,"#etarget"],[8125,"#google_hirdetes"],[44590,"#google_hirdetesek"],[60431,"#google-hirdetes"],[31708,"#google-hirdetesek"],[52115,"#googlehirdetes"],[37768,"#googlehirdetesek"],[60069,"#hirdetes_box"],[21921,"#hirdetes_container,\n#hirdetes-container"],[26728,"#hirdetes_doboz"],[50432,"#hirdetes_linkek"],[63639,"#hirdetes-box"],[9178,"#hirdetes-doboz"],[54962,"#hirdetes-linkek"],[9954,"#hirdetesek_box"],[29086,"#hirdetesek_container,\n#hirdetesek-container"],[9427,"#hirdetesek_doboz"],[7184,"#hirdetesek-box"],[18657,"#hirdetesek-doboz"],[29201,"#optimonk-iframe-container-campaign-12"],[11953,"#optimonk-overlay-campaign-12"],[7578,"#reklam-doboz"],[26483,"#reklamok"]]);
const highlyGeneric = /* 14 */"[class*=\"GoogleAds\"],\n[data-campaign-name^=\"ads\"],\n[href*=\"ad.adverticum.net\"],\n[id*=\"google_ads\"],\n[id*=\"GoogleAds\"],\n[id^=\"ad_zone_\"],\n[id^=\"adocean\"],\n[id^=\"googlead\"],\n[name*=\"google_ads\"],\na[href*=\"ad.eval.hu\"],\na[href*=\"ad.netmedia.hu\"],\na[href*=\"adverticum.net\"],\na[href*=\"daserver.ultraweb.hu\"],\niframe[id*=\"ETARGET-\"]";
const exceptions = /* 5 */[".adBanner",".ad-box:not(#ad-banner):not(:empty)",".heateor_sss_sharing_container",".adBanner","[href*=\"ad.adverticum.net\"]"];
const hostnames = /* 5 */["videa.hu","media1.hu","greendex.hu","videaloop.hu","mindmegette.hu"];
const hasEntities = false;

self.genericSelectorMaps = self.genericSelectorMaps ?? [];
self.genericSelectorMaps.push(lowlyGeneric);
self.genericDetails = self.genericDetails ?? [];
self.genericDetails.push({ highlyGeneric, exceptions, hostnames, hasEntities });

})();

/******************************************************************************/
