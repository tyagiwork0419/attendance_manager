import { describe, expect, it, vi } from 'vitest';
import { createDriveClient } from '../src/google/drive.js';

function makeFilesApi(overrides: Partial<Record<string, any>> = {}) {
  return {
    list: vi.fn(async () => ({ data: { files: [] } })),
    copy: vi.fn(async () => ({ data: { id: 'new-id' } })),
    ...overrides,
  };
}

function makeAuthStub() {
  return {} as any;
}

describe('createDriveClient', () => {
  it('findFileInFolder returns the file id when a match exists', async () => {
    const filesApi = makeFilesApi({
      list: vi.fn(async () => ({ data: { files: [{ id: 'file-1', name: '2026年' }] } })),
    });
    const client = createDriveClient(makeAuthStub(), { files: filesApi } as any);

    const id = await client.findFileInFolder('folder-1', '2026年');
    expect(id).toBe('file-1');
    expect(filesApi.list).toHaveBeenCalledWith(
      expect.objectContaining({
        q: expect.stringContaining("'folder-1' in parents"),
      })
    );
  });

  it('findFileInFolder returns null when nothing matches', async () => {
    const filesApi = makeFilesApi();
    const client = createDriveClient(makeAuthStub(), { files: filesApi } as any);
    expect(await client.findFileInFolder('folder-1', 'missing')).toBeNull();
  });

  it('listFileNamesInFolder collects names across pages', async () => {
    const filesApi = makeFilesApi({
      list: vi
        .fn()
        .mockResolvedValueOnce({
          data: { files: [{ name: '2024年' }], nextPageToken: 'p2' },
        })
        .mockResolvedValueOnce({ data: { files: [{ name: '2025年' }] } }),
    });
    const client = createDriveClient(makeAuthStub(), { files: filesApi } as any);

    const names = await client.listFileNamesInFolder('folder-1');
    expect(names).toEqual(['2024年', '2025年']);
    expect(filesApi.list).toHaveBeenCalledTimes(2);
  });

  it('copyFile returns the new file id without specifying a destination parent', async () => {
    const filesApi = makeFilesApi({
      copy: vi.fn(async () => ({ data: { id: 'copied-id' } })),
    });
    const client = createDriveClient(makeAuthStub(), { files: filesApi } as any);

    const id = await client.copyFile('template-id', '2026年');
    expect(id).toBe('copied-id');
    expect(filesApi.copy).toHaveBeenCalledWith({
      fileId: 'template-id',
      requestBody: { name: '2026年' },
    });
  });

  it('copyFile throws if the API does not return a new id', async () => {
    const filesApi = makeFilesApi({ copy: vi.fn(async () => ({ data: {} })) });
    const client = createDriveClient(makeAuthStub(), { files: filesApi } as any);
    await expect(client.copyFile('template-id', '2026年')).rejects.toThrow();
  });
});
