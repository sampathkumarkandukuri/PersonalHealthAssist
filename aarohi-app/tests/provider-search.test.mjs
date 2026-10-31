import {test} from 'node:test';
import assert from 'node:assert/strict';
import {providerSearch} from '../web/src/lib.js';
test('retailer search preserves special characters as a single query',()=>{const r=providerSearch({WebsiteUrl:'https://blinkit.com/'},'oil & ghee + 1L');const u=new URL(r.url);assert.equal(u.searchParams.get('q'),'oil & ghee + 1L');assert.equal(u.pathname,'/search');assert.equal(r.kind,'retailer')});
test('unconfigured providers get explicitly labelled site web search',()=>{const r=providerSearch({WebsiteUrl:'https://www.netmeds.com/'},'sample medicine 500 mg');assert.equal(r.kind,'web');assert.equal(new URL(r.url).searchParams.get('q'),'site:netmeds.com sample medicine 500 mg')});
test('blank queries keep homepage and unsafe URLs are rejected',()=>{assert.equal(providerSearch({WebsiteUrl:'https://blinkit.com/'},'  ').kind,'website');assert.equal(providerSearch({WebsiteUrl:'javascript:alert(1)'},'oil'),null)});
