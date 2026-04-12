import { Request } from 'express';

export type AuthenticatedRequest = Request & {
  user: {
    userId: string;
    email: string;
  };
};
