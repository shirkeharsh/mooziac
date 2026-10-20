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

// annoyances-widgets

// Important!
// Isolate from global scope
(function uBOL_cssGenericImport() {

const lowlyGeneric = new Map(/* 13 */[[47973,"#WACLauncher__Button"],[63696,"#popin-salescontact"],[40023,"#rasaWebchatPro"],[5431,"#seaspaceai-agent"],[62607,".b24-widget-button-wrapper"],[63938,".chat_hammerbot-iframe-wrapper__outer"],[57562,".drift-facade"],[62267,".intercom-launcher"],[64381,".intercom-lightweight-app"],[38969,".joinchat--chatbox"],[37423,".m-chat-toggler"],[25581,".sticky-button--whatsapp"],[28360,".wix-blog-hide-in-print.SITE_FOOTER_WRAPPER"]]);
const highlyGeneric = /* 1 */"yardi-widget-craigslist";
const exceptions = /* 0 */[];
const hostnames = /* 0 */[];
const hasEntities = false;

self.genericSelectorMaps = self.genericSelectorMaps ?? [];
self.genericSelectorMaps.push(lowlyGeneric);
self.genericDetails = self.genericDetails ?? [];
self.genericDetails.push({ highlyGeneric, exceptions, hostnames, hasEntities });

})();

/******************************************************************************/
