import { drive_v3, google } from 'googleapis';
import type { JWT } from 'google-auth-library';

export interface DriveClient {
  /** フォルダ内を名前で検索する。見つからなければ null。 */
  findFileInFolder(folderId: string, fileName: string): Promise<string | null>;
  /** フォルダ直下のファイル名一覧（ページングをすべて辿る）。 */
  listFileNamesInFolder(folderId: string): Promise<string[]>;
  /** ファイルをコピーする。コピー先の親フォルダは元ファイルと同じになる。 */
  copyFile(fileId: string, newName: string): Promise<string>;
}

/** Driveの検索クエリに埋め込む文字列内のシングルクォートをエスケープする。 */
function escapeForQuery(value: string): string {
  return value.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

export function createDriveClient(
  auth: JWT,
  api: Pick<drive_v3.Drive, 'files'> = google.drive({ version: 'v3', auth })
): DriveClient {
  return {
    async findFileInFolder(folderId, fileName) {
      const response = await api.files.list({
        q: `'${folderId}' in parents and name = '${escapeForQuery(fileName)}' and trashed = false`,
        fields: 'files(id, name)',
        pageSize: 1,
      });
      const file = response.data.files?.[0];
      return file?.id ?? null;
    },

    async listFileNamesInFolder(folderId) {
      const names: string[] = [];
      let pageToken: string | undefined;

      do {
        const response = await api.files.list({
          q: `'${folderId}' in parents and trashed = false`,
          fields: 'nextPageToken, files(name)',
          pageSize: 1000,
          pageToken,
        });
        for (const file of response.data.files ?? []) {
          if (file.name) {
            names.push(file.name);
          }
        }
        pageToken = response.data.nextPageToken ?? undefined;
      } while (pageToken);

      return names;
    },

    async copyFile(fileId, newName) {
      const response = await api.files.copy({
        fileId,
        requestBody: { name: newName },
      });
      if (!response.data.id) {
        throw new Error(`ファイルのコピーに失敗しました: ${fileId}`);
      }
      return response.data.id;
    },
  };
}
