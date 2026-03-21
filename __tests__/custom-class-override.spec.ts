import fs from 'fs';
import path from 'path';
import { GluaApiWriter } from '../src/api-writer/glua-api-writer.js';
import { ClassFunction, Struct } from '../src/scrapers/wiki-page-markup-scraper.js';

describe('Custom class overrides emission', () => {
	const tmpDir = path.join(process.cwd(), 'output_test_tmp');

	beforeAll(() => {
		if (!fs.existsSync(tmpDir)) fs.mkdirSync(tmpDir, { recursive: true });
	});

	beforeEach(() => {
		if (fs.existsSync(tmpDir)) {
			fs.rmSync(tmpDir, { recursive: true, force: true });
		}

		fs.mkdirSync(tmpDir, { recursive: true });
	});

	afterAll(() => {
		if (fs.existsSync(tmpDir)) {
			fs.rmSync(tmpDir, { recursive: true, force: true });
		}
	});

	test('orphan class override (class.ENT) is written when no wiki page exists', () => {
		const writer = new GluaApiWriter(tmpDir);
		writer.addOverride('class.ENT', '---@class ENT\nENT = {}\n');
		writer.writeToDisk();
		const customFile = path.join(tmpDir, 'custom_classes.lua');
		expect(fs.existsSync(customFile)).toBe(true);
		const content = fs.readFileSync(customFile, 'utf8');
		expect(content).toMatch(/@class ENT/);
		expect(content).toMatch(/ENT = {}/);
	});

	test('class override is emitted inline for generated class method files', () => {
		const writer = new GluaApiWriter(tmpDir);
		writer.addOverride('class.Vector', '---@class Vector\n---@field x number\nlocal Vector = {}\n');

		const vectorFile = path.join(tmpDir, 'vector.lua');
		writer.writePages([<ClassFunction>{
			type: 'classfunc',
			name: 'Add',
			address: 'Vector:Add',
			parent: 'Vector',
			description: 'Adds another vector.',
			realm: 'shared',
			url: 'na',
			arguments: [{
				args: [{
					name: 'vector',
					type: 'Vector',
					description: 'The vector to add.',
				}],
			}],
		}], vectorFile);

		writer.writeToDisk();

		const vectorContent = fs.readFileSync(vectorFile, 'utf8');
		expect(vectorContent).toMatch(/---@class Vector/);
		expect(vectorContent).toMatch(/local Vector = \{\}/);
		expect(vectorContent).toMatch(/function Vector:Add\(vector\) end/);

		const customFile = path.join(tmpDir, 'custom_classes.lua');
		if (fs.existsSync(customFile)) {
			const customContent = fs.readFileSync(customFile, 'utf8');
			expect(customContent).not.toMatch(/---@class Vector/);
		}
	});

	test('alias-named class override is emitted inline for canonical class methods', () => {
		const writer = new GluaApiWriter(tmpDir);
		writer.addOverride('class.TOOL', '---@class Tool\nTool = {}\n\n---@class TOOL : Tool\nTOOL = Tool\n');

		const toolFile = path.join(tmpDir, 'tool.lua');
		writer.writePages([<ClassFunction>{
			type: 'classfunc',
			name: 'Allowed',
			address: 'Tool:Allowed',
			parent: 'Tool',
			description: 'Returns whether the tool is allowed.',
			realm: 'shared',
			url: 'na',
		}], toolFile);

		writer.writeToDisk();

		const toolContent = fs.readFileSync(toolFile, 'utf8');
		expect(toolContent).toMatch(/---@class Tool/);
		expect(toolContent).toMatch(/Tool = \{\}/);
		expect(toolContent).toMatch(/---@class TOOL : Tool/);
		expect(toolContent).toMatch(/TOOL = Tool/);
		expect(toolContent).toMatch(/function Tool:Allowed\(\) end/);

		const customFile = path.join(tmpDir, 'custom_classes.lua');
		if (fs.existsSync(customFile)) {
			const customContent = fs.readFileSync(customFile, 'utf8');
			expect(customContent).not.toMatch(/---@class Tool/);
			expect(customContent).not.toMatch(/---@class TOOL : Tool/);
		}
	});

	test('alias-named struct page emits the matching custom class block', () => {
		const writer = new GluaApiWriter(tmpDir);
		writer.addOverride('class.TOOL', '---@class Tool\nTool = {}\n\n---@class TOOL : Tool\nTOOL = Tool\n');

		const structuresFile = path.join(tmpDir, 'structures.lua');
		writer.writePages([<Struct>{
			type: 'struct',
			name: 'TOOL',
			address: 'TOOL',
			description: 'Tool data.',
			realm: 'shared',
			fields: [{
				name: 'Mode',
				type: 'string',
				description: 'Tool mode.',
			}],
		}], structuresFile);

		writer.writeToDisk();

		const structuresContent = fs.readFileSync(structuresFile, 'utf8');
		expect(structuresContent).toMatch(/---@class Tool/);
		expect(structuresContent).toMatch(/Tool = \{\}/);
		expect(structuresContent).toMatch(/---@class TOOL : Tool/);
		expect(structuresContent).toMatch(/TOOL = Tool/);
		expect(structuresContent).toMatch(/TOOL.Mode = nil/);

		const customFile = path.join(tmpDir, 'custom_classes.lua');
		if (fs.existsSync(customFile)) {
			const customContent = fs.readFileSync(customFile, 'utf8');
			expect(customContent).not.toMatch(/---@class Tool/);
			expect(customContent).not.toMatch(/---@class TOOL : Tool/);
		}
	});
});
